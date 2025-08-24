# Create a file and its parent directories if they don't exist
# Usage: mktouch /path/to/file.txt
mktouch() {
  for file in "$@"; do
    mkdir -p "$(dirname "$file")" && touch "$file"
  done
}
