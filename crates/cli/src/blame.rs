/*!
This module provides functionality for fetching git blame information for files.
*/

use std::{
    collections::HashMap,
    path::Path,
    process::{Command, Stdio},
    sync::{Arc, Mutex},
};

/// A cache for git blame information to avoid repeated git blame calls
/// for the same file. This is important for performance when searching
/// files with multiple matches.
#[derive(Debug, Clone)]
pub struct BlameCache {
    cache: Arc<Mutex<HashMap<String, HashMap<u64, BlameInfo>>>>,
}

impl BlameCache {
    /// Create a new empty blame cache.
    pub fn new() -> BlameCache {
        BlameCache {
            cache: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    /// Get blame information for a specific line in a file.
    /// Returns None if the information is not available (e.g., file not in git).
    pub fn get_blame(
        &self,
        file_path: &Path,
        line_number: u64,
    ) -> Option<BlameInfo> {
        let path_str = file_path.to_string_lossy().to_string();

        // Check cache first
        {
            let cache = self.cache.lock().unwrap();
            if let Some(file_blames) = cache.get(&path_str) {
                return file_blames.get(&line_number).cloned();
            }
        }

        // If not in cache, fetch all blame info for the file
        self.fetch_file_blame(file_path);

        // Try again from cache
        let cache = self.cache.lock().unwrap();
        cache
            .get(&path_str)
            .and_then(|file_blames| file_blames.get(&line_number).cloned())
    }

    /// Fetch blame information for an entire file and store it in the cache.
    fn fetch_file_blame(&self, file_path: &Path) {
        let path_str = file_path.to_string_lossy().to_string();

        // Convert to absolute path and determine the working directory for git
        let abs_path = match file_path.canonicalize() {
            Ok(p) => p,
            Err(_) => {
                // If we can't canonicalize, cache empty and return
                let mut cache = self.cache.lock().unwrap();
                cache.insert(path_str, HashMap::new());
                return;
            }
        };

        // Find the git repository root by looking for .git directory
        let git_dir = find_git_dir(&abs_path);

        // Determine what path to pass to git blame
        let (working_dir, blame_path) = if let Some(ref git_root) = git_dir {
            // Run git from the repo root with a relative path
            let rel_path = abs_path.strip_prefix(git_root).unwrap_or(&abs_path);
            (Some(git_root.as_path()), rel_path)
        } else {
            // No git repo found, run from file's directory with just filename
            (abs_path.parent(), abs_path.as_path())
        };

        let mut cmd = Command::new("git");
        cmd.arg("blame")
            .arg("--porcelain")
            .arg(blame_path)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::null());

        if let Some(dir) = working_dir {
            cmd.current_dir(dir);
        }

        // Use porcelain format which is easier to parse
        let output = match cmd.output() {
            Ok(output) if output.status.success() => output,
            _ => {
                // If git blame fails, cache an empty map for this file
                // so we don't keep trying
                let mut cache = self.cache.lock().unwrap();
                cache.insert(path_str, HashMap::new());
                return;
            }
        };

        let stdout = String::from_utf8_lossy(&output.stdout);
        let blame_map = parse_git_blame_porcelain(&stdout);

        let mut cache = self.cache.lock().unwrap();
        cache.insert(path_str, blame_map);
    }
}

impl Default for BlameCache {
    fn default() -> Self {
        Self::new()
    }
}

/// Information about a single line from git blame.
#[derive(Debug, Clone)]
pub struct BlameInfo {
    /// The abbreviated commit hash (first 8 characters)
    pub commit_hash: String,
    /// The author name
    pub author: String,
    /// The commit timestamp in a human-readable format
    pub timestamp: String,
}

impl BlameInfo {
    /// Format the blame information as a string for display.
    /// Format: "<commit> <author> <time>"
    pub fn format(&self) -> String {
        format!("{} {} {}", self.commit_hash, self.author, self.timestamp)
    }

    /// Format the blame information with fixed widths for consistent alignment.
    /// This ensures the output columns line up nicely.
    pub fn format_fixed_width(&self) -> String {
        format!(
            "{:<8} {:<15} {:<10}",
            &self.commit_hash[..self.commit_hash.len().min(8)],
            truncate_str(&self.author, 15),
            &self.timestamp
        )
    }
}

/// Truncate a string to a maximum length, adding "..." if truncated.
fn truncate_str(s: &str, max_len: usize) -> String {
    if s.len() <= max_len {
        format!("{:<width$}", s, width = max_len)
    } else {
        format!("{}...", &s[..max_len.saturating_sub(3)])
    }
}

/// Parse the porcelain format output from git blame.
/// Returns a map from line number to BlameInfo.
fn parse_git_blame_porcelain(output: &str) -> HashMap<u64, BlameInfo> {
    let mut result = HashMap::new();
    let mut commit_cache: HashMap<String, (String, String)> = HashMap::new();
    let lines: Vec<&str> = output.lines().collect();
    let mut i = 0;

    while i < lines.len() {
        let line = lines[i];

        // Each blame entry starts with: <commit-hash> <original-line> <final-line> <num-lines>
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() < 3 {
            i += 1;
            continue;
        }

        let commit_hash = parts[0].to_string();
        let final_line_str = parts[2];
        let final_line: u64 = match final_line_str.parse() {
            Ok(n) => n,
            Err(_) => {
                i += 1;
                continue;
            }
        };

        i += 1; // Move to next line

        // Check if we've seen this commit before
        let (author, timestamp) = if let Some(cached) = commit_cache.get(&commit_hash) {
            // For cached commits, just skip to the code line (starts with tab)
            while i < lines.len() && !lines[i].starts_with('\t') {
                i += 1;
            }
            cached.clone()
        } else {
            // Parse the metadata lines that follow for a new commit
            let mut author = String::from("Unknown");
            let mut timestamp = String::from("");

            while i < lines.len() {
                let metadata_line = lines[i];

                if metadata_line.starts_with("author ") {
                    author = metadata_line.strip_prefix("author ").unwrap_or("Unknown").to_string();
                } else if metadata_line.starts_with("author-time ") {
                    if let Some(time_str) = metadata_line.strip_prefix("author-time ") {
                        if let Ok(timestamp_secs) = time_str.parse::<i64>() {
                            timestamp = format_timestamp(timestamp_secs);
                        }
                    }
                } else if metadata_line.starts_with('\t') {
                    // This is the actual code line, end of this entry
                    break;
                }

                i += 1;
            }

            // Cache this commit's info
            commit_cache.insert(commit_hash.clone(), (author.clone(), timestamp.clone()));
            (author, timestamp)
        };

        // Handle uncommitted changes (all zeros hash)
        let (author, timestamp) = if commit_hash == "0000000000000000000000000000000000000000" {
            (String::from("Uncommitted"), String::from("now"))
        } else {
            (author, timestamp)
        };

        result.insert(
            final_line,
            BlameInfo {
                commit_hash: commit_hash[..commit_hash.len().min(8)].to_string(),
                author,
                timestamp,
            },
        );

        i += 1; // Move past the code line
    }

    result
}

/// Find the git repository root by walking up the directory tree from the given path.
/// Returns the path to the directory containing .git, or None if not found.
fn find_git_dir(start_path: &Path) -> Option<std::path::PathBuf> {
    let mut current = start_path;

    // Start from the file's directory
    if current.is_file() {
        current = current.parent()?;
    }

    loop {
        let git_path = current.join(".git");
        if git_path.exists() {
            return Some(current.to_path_buf());
        }

        // Move up to parent directory
        current = current.parent()?;
    }
}

/// Format a Unix timestamp as a relative time string (e.g., "2d ago", "3w ago")
fn format_timestamp(timestamp_secs: i64) -> String {
    use std::time::{SystemTime, UNIX_EPOCH};

    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64;

    let diff = now - timestamp_secs;

    if diff < 60 {
        format!("{}s ago", diff)
    } else if diff < 3600 {
        format!("{}m ago", diff / 60)
    } else if diff < 86400 {
        format!("{}h ago", diff / 3600)
    } else if diff < 604800 {
        format!("{}d ago", diff / 86400)
    } else if diff < 2592000 {
        format!("{}w ago", diff / 604800)
    } else if diff < 31536000 {
        format!("{}mo ago", diff / 2592000)
    } else {
        format!("{}y ago", diff / 31536000)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_blame_cache_creation() {
        let cache = BlameCache::new();
        assert!(cache.cache.lock().unwrap().is_empty());
    }

    #[test]
    fn test_blame_info_format() {
        let info = BlameInfo {
            commit_hash: "abc12345".to_string(),
            author: "John Doe".to_string(),
            timestamp: "2d ago".to_string(),
        };
        assert_eq!(info.format(), "abc12345 John Doe 2d ago");
    }

    #[test]
    fn test_truncate_str() {
        assert_eq!(truncate_str("short", 10), "short     ");
        assert_eq!(truncate_str("this is a very long string", 10), "this is...");
    }
}
