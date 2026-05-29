function mktouch --description 'Create files and their parent directories'
    for file in $argv
        mkdir -p (dirname $file); and touch $file
    end
end
