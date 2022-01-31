module Haml2Slim
  class Converter
    def initialize(haml)
      @slim = ""

      haml.each_line do |line|
        @slim << parse_line(line)
      end
    end

    def to_s
      @slim
    end

    def parse_line(line)
      indent = line[/^[ \t]*/]
      line.strip!

      # removes the HAML's whitespace removal characters ('>' and '<')
      line.gsub!(/(>|<)$/, '')

      converted =
        case line[0, 2]
        when '&=' then line.sub(/^&=/, '==')
        when '!=' then line.sub(/^!=/, '==')
        when '-#' then line.sub(/^-#/, '/')
        when '#{' then "| #{line}"
        else
          case line[0]
          when ?%, ?., ?# then parse_tag(line)
          when ?:         then "#{line[1..-1]}:"
          when ?!         then line == "!!!" ? line.sub(/^!!!/, 'doctype html') : line.sub(/^!!!/, 'doctype')
          when ?-, ?=     then line
          when ?~         then line.sub(/^~/, '=')
          when ?/         then line.sub(/^\//, '/!')
          when ?\         then line.sub(/^\\/, '|')
          when nil        then ""
          else "| #{line}"
          end
      end

      if converted.chomp!(' |')
        converted.sub!(/^\| /, '')
        converted << ' \\'
      end

      "#{indent}#{converted}\n"
    end

    def parse_tag(tag_line)
      tag_line.sub!(/^%/, '')
      tag_line.sub!(/^([a-zA-Z_\.\-]+)=/, '\1 =')
      tag_line.sub!(/^([a-zA-Z_\.\-]+)!=/, '\1 ==')

      if tag_line_contains_attr = tag_line.match(/^([a-zA-Z_\.\-]+)\{(.+)\}(.*)/)
        tag, attrs, text = *tag_line_contains_attr[1..3]
        "#{tag} #{parse_attrs(attrs)} #{text}"
      else
        tag_line.sub(/^!=/, '=')
      end
    end

    def parse_attrs(attrs, key_prefix="")
      data_temp = {}

      [
        /data:\s*\{\s*([^\}]*)\s*\}/, # { a: b } (Ruby 1.7 Hash Syntax)
        /:data\s*=>\s*\{([^\}]*)\s*\}/, # { a => b }
      ].each do |regexp|
        attrs.gsub!(regexp) do
          key = rand(99999).to_s
          data_temp[key] = parse_attrs($1, "data-")
          ":#{key} => #{key}"
        end
      end

      [
        /,?( ?):?('|")?([^"'{ ]+)('|")?:\s*(:?[^,]*)/, # { a: b } (Ruby 1.7 Hash Syntax)
        /,?( ?):?('|")?([^"'{ ]+)('|")?\s*=>\s*(:?[^,]*)/, # { a => b }
      ].each do |regexp|
        attrs.gsub!(regexp) do
          space = $1
          key = $3
          value = $5.strip
          wrapped_value = value.to_s =~ /\s+/ ? "(#{value})" : value
          wrapped_value = wrapped_value.start_with?(":") ? "\"#{wrapped_value.delete(':')}\"" : wrapped_value
          "#{space}#{key_prefix}#{key}=#{wrapped_value}"
        end
      end

      data_temp.each do |k, v|
        attrs.gsub!("#{k}=#{k}", v)
      end

      attrs
    end
  end
end
