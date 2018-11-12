#!/usr/bin/env ruby
require 'getoptlong'
require 'mini_magick'


opts = GetoptLong.new(
  [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
  [ '--output', '-o', GetoptLong::OPTIONAL_ARGUMENT ],
  [ '--rotate', '-r', GetoptLong::OPTIONAL_ARGUMENT ],
  [ '--flip_h', GetoptLong::OPTIONAL_ARGUMENT ],
  [ '--flip_v', GetoptLong::OPTIONAL_ARGUMENT ],
  [ '--info', '-i', GetoptLong::OPTIONAL_ARGUMENT ],
  [ '--array', '-a', GetoptLong::OPTIONAL_ARGUMENT ]
)

file = nil
save = false
output = nil
flip_h = false
flip_v = false
rotate = false
rotation = 0
info = false
array = false

def help
    puts <<-EOF
\033[1mNAME\033[0m
        cttp - convert image to (thermal) printable data

\033[1mSYNOPSIS\033[0m
        \033[1mcttp\033[0m FILE [OPTION]...

\033[1mDESCRIPTION\033[0m
        Convert To Thermal Printable data (cttp); Convert image file to black and white only and create data file printable by thermal printer.

        FILE: The file to convert.

        \033[1m-h, --help\033[0m
            show help

        \033[1m-o filename, --output filename\033[0m
            Save data in an ouput file named filename; must follow 8.3 format (8 max char name + 3 max char extension max) for arduino SD module compatibility
            Default filename is data

        \033[1m-a, --array\033[0m
            Print the data in a C++ array form like:
            data: {0x00, ...}

        \033[1m-i, --info\033[0m
            Print converted image dimensions and size
        
        \033[1m-r x, --rotate x\033[0m
            rotate the image by x degrees

        \033[1m--flip_h\033[0m
            flip the image horizontally
           
        \033[1m--flip_v\033[0m
            flip the image vertically
    EOF
end

opts.each do |opt, arg|
  case opt
    when '--help'
      help
      exit 0
    when '--output'
      output = arg == '' ? 'data' : arg
      save = true
    when '--rotate'
        if arg.number?
            rotate = true
            rotation = arg
        end
    when '--flip_h'
        flip_h = true
    when '--flip_v'
        flip_v = true
    when '--info'
      info = true
    when '--array'
        array = true
  end
end

if ARGV.length != 1
    puts "cttp: missing file operand"
    puts "Try 'cttp --help' for more information."
    exit 0
end

file = ARGV.shift

if !array && !save && !info
    puts "cttp: nothing to do"
    puts "Try 'cttp --help' for more information."
    exit 0
end

# Printer accept files encoded as follow:
# - Each bit stand for one pixel. 0 is white, 1 is black (burned).
# - Those bits are written as 8 bits long integer, byte by byte.
img = MiniMagick::Image.open(file)

img.format :bmp
img.type :bilevel       # Convert to B&W only,
                        # pixels are array of either
                        # [0,0,0] or [255,255,255]

pixel_idx = 0
byte = 0
bytes = []

img.flip if flip_v
img.flop if flip_h
img.rotate rotation if rotate

img.get_pixels.each do |row|
    row.each do |pixel|
        # Return 1 for black (0) or 0 for white (255)
        # Shift the result to the right position in the byte. First
        # pixel is on the left: it must be shifted by 7
        byte += pixel.first == 0 ? (1 << (7 - pixel_idx)) : 0
        pixel_idx += 1
        if (pixel_idx >= 8)
            pixel_idx = 0
            bytes.push(byte)
            byte = 0
        end
    end
    if pixel_idx > 0 # width is not divisible by 8
        pixel_idx = 0
        bytes.push(byte)
        byte = 0
    end
end

if array
    puts 'data:   {' + bytes.map{|e| format '0x%02x', e }.join(',') + '}'
end

if info
    puts 'size:   ' + bytes.length.to_s + ' bytes'
    puts 'width:  ' + ((img.width+7)/8*8).to_s + ' px'  # rounded to closest 8 multiple
    puts 'height: ' + img.height.to_s + ' px'
end

if save
    f = File.new(output,  "wb") # Open the file in bit mode
    bytes.each do |byte|
        f.print(byte.chr)   
    end
    f.close
end
