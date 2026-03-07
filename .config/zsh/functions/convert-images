local source_ext="$1"
local target_ext="${2:-avif}"
local quality="${3:-85}"

if [[ -z "$source_ext" ]]; then
    echo "Usage: convert-images <source_ext> [target_ext] [quality]"
    echo "Example: convert-images jpg avif 85"
    return 1
fi

# Check if any files with the source extension exist
local files=(*."$source_ext"(N))  # (N) is zsh's NULL_GLOB option

if [[ ${#files[@]} -eq 0 ]]; then
    echo "No .$source_ext files found in current directory"
    return 1
fi

echo "Converting ${#files[@]} .$source_ext files to .$target_ext with quality $quality..."

magick convert -quality "$quality" *."$source_ext" \
    -set filename:base "%[basename]" \
    "%[filename:base].$target_ext"

echo "Conversion complete!"
