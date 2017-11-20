# This function optimizes a pdf using pdf2ps and ps2pdf.
# It creates a file in the current working directory with the name of the original
# file with the suffix -opt in front of the extension.
# You are supposed to either paste this into your .bashrc, paste it into your current shell or include it in your bashrc via . or source.
# You can then call this function by using its name and the file name as the first argument.
function optimizepdf {
    pdf2ps "$1" /dev/stdout | ps2pdf /dev/stdin "${1%.pdf}-opt.pdf"
}