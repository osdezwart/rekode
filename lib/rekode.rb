=begin
/***************************************************************************
 *   Copyright (C) 2006, Paul Lutus                                        *
 *   Copyright (C) 2008, Antono Vasiljev                                   *
 *   Copyright (C) 2010, Olle de Zwart                                     *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
 ***************************************************************************/
=end
module Rekode

  VERSION = '0.1'

  class Indenter

    # indent regexp
    INDENT_EXP = [
      /^def\b/,
      /^if\b/,
      /^else\b/,
      /^elsif\b/,
      /\bdo\b/,
      /^class\b/,
      /^module\b/,
      /(=\s*|^)until\b/,
      /(=\s*|^)for\b/,
      /^unless\b/,
      /(=\s*|^)while\b/,
      /(=\s*|^)begin\b/,
      /(^| )case\b/,
      /\bthen\b/,
      /^rescue\b/,
      /^ensure\b/,
      /\bwhen\b/,
      /\{[^\}]*$/,
      /\[[^\]]*$/
    ]

    # outdent regexp
    OUTDENT_EXP = [
      /^end\b/,
      /^else\b/,
      /^elsif\b/,
      /^rescue\b/,
      /^ensure\b/,
      /\bwhen\b/,
      /^[^\{]*\}/,
      /^[^\[]*\]/
    ]

    # Creates cleaner. Takes hash of parametrs:
    #
    # :indent_char - indent symbol (default: space)
    #
    # :indent_size - quantity of indent symbols for single step (default: 2)
    #
    def initialize(params = {})
      @indent_char = params[:indent_char] || " "
      @indent_size = params[:indent_size] || 2
    end

    # Cleaning source. Takes hash of parametrs:
    #
    # :file   - Source code as path to file
    #
    # :text   - Source code as ruby string
    #
    # :backup - makes backup copy if true
    #
    # :indent_char - indent symbol (default: " ")
    #
    # :indent_size - quantity of indent symbols for single step
    #
    #
    def self.process(params = {})
      unless params[:file].nil?
        params[:text] = File.read(params[:file])
        @path = params[:file]
      end

      output = self.new(params).process(params[:text])

      if params[:backup] && (output != params[:text]) && params[:file]
        File.open(params[:file] + ".ugly~","w") { |f| f.write(params[:text]) }
        File.open(params[:file],"w") { |f| f.write(output) }
      else
        return output
      end

    end


    # Cleaning source. Takes source code as ruby string.
    #
    def process(source)

      cursor_inside_comment_block = false
      cursor_at_program_end       = false

      multiline_array  = []
      multiline_string = ""

      indent_level  = 0
      dest          = ""

      source.each_line do |line|

        unless cursor_at_program_end

          # detect program end mark
          if line =~ /^__END__$/
            cursor_at_program_end = true
          else

            # combine continuing lines
            if(!(line =~ /^\s*#/) && line =~ /[^\\]\\\s*$/)
              multiline_array.push line
              multiline_string += line.sub(/^(.*)\\\s*$/,"\\1")
              next
            end

            # add final line
            if (multiline_string.length > 0)
              multiline_array.push line
              multiline_string += line.sub(/^(.*)\\\s*$/,"\\1")
            end

            tline = ((multiline_string.length > 0) ? multiline_string : line).strip

            cursor_inside_comment_block = true if tline.match(/^=begin/)
          end
        end

        if (cursor_inside_comment_block or cursor_at_program_end)
          dest += line # add the line unchanged
        else

          cursor_at_comment_line = (tline =~ /^#/)

          unless cursor_at_comment_line
            # throw out sequences that will
            # only sow confusion
            # XXX WTF?
            while tline.gsub!(/\{[^\{]*?\}/,"")
            end
            while tline.gsub!(/\[[^\[]*?\]/,"")
            end
            while tline.gsub!(/'.*?'/,"")
            end
            while tline.gsub!(/".*?"/,"")
            end
            while tline.gsub!(/\`.*?\`/,"")
            end
            while tline.gsub!(/\([^\(]*?\)/,"")
            end
            while tline.gsub!(/\/.*?\//,"")
            end
            while tline.gsub!(/%r(.).*?\1/,"")
            end

            # delete end-of-line comments
            tline.sub!(/#[^\"]+$/,"")
            # convert quotes
            # WTF?
            tline.gsub!(/\\\"/,"'")
            OUTDENT_EXP.each do |re|
              if (tline =~ re)
                indent_level -= 1
                break
              end
            end
          end

          unless multiline_array.empty?
            multiline_array.each do |ml|
              dest += add_line(ml,indent_level)
            end
            multiline_array.clear
            multiline_string = ""
          else
            dest += add_line(line,indent_level)
          end

          unless cursor_at_comment_line
            INDENT_EXP.each do |re|
              if(tline =~ re && !(tline =~ /\s+end\s*$/))
                indent_level += 1
                break
              end
            end
          end

        end

        cursor_inside_comment_block = false if tline =~ /^=end/
      end


      if (indent_level != 0)
        STDERR.puts "#{@path}: Indentation error: #{indent_level}" if @path
      end

      return dest
    end

    private

    def make_indent(indent_level)
      return (indent_level < 0) ? "" : @indent_char * @indent_size * indent_level
    end

    def add_line(line,indent_level)
      line.strip!
      line = make_indent(indent_level)+line if line.length > 0
      return line + "\n"
    end

  end

end
