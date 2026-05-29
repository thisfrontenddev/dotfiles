function convert-images --description 'Batch-convert images by extension (default target avif, quality 85)'
    set -l source_ext $argv[1]
    set -l target_ext avif
    set -l quality 85
    test (count $argv) -ge 2; and set target_ext $argv[2]
    test (count $argv) -ge 3; and set quality $argv[3]

    if test -z "$source_ext"
        echo "Usage: convert-images <source_ext> [target_ext] [quality]"
        echo "Example: convert-images jpg avif 85"
        return 1
    end

    # `set` tolerates an empty glob (no error), unlike a bare command argument.
    set -l files *.$source_ext
    if not set -q files[1]
        echo "No .$source_ext files found in current directory"
        return 1
    end

    echo "Converting "(count $files)" .$source_ext files to .$target_ext with quality $quality..."
    magick -quality $quality *.$source_ext \
        -set filename:base "%[basename]" \
        "%[filename:base].$target_ext"
    echo "Conversion complete!"
end
