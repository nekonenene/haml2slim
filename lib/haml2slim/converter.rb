module Haml2Slim
  class Converter
    def initialize(haml)
      @slim = ''

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

      if line_contains_vue_interpolation = line.match(/^(.+) (\{\{.+\}\})$/)
        line = line_contains_vue_interpolation[1]
        vue_interpolation = line_contains_vue_interpolation[2]
      end

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

      if vue_interpolation.nil?
        "#{indent}#{converted}\n"
      else
        "#{indent}#{converted}\n#{indent}  | #{vue_interpolation}\n"
      end
    end

    def parse_tag(tag_line)
      tag_line.sub!(/^%/, '')
      tag_line.sub!(/^([\w#\.\-]+)=/, '\1 =')
      tag_line.sub!(/^([\w#\.\-]+)!=/, '\1 ==')
      # Avoid syntax errors caused by attributes wrapper characters
      tag_line.sub!(/^([\w#\.\-]+ )\(/, '\1&#40;')
      tag_line.sub!(/^([\w#\.\-]+ )\[/, '\1&#91;')
      tag_line.sub!(/^([\w#\.\-]+ )\{/, '\1&#123;')

      if tag_line_contains_attr = tag_line.match(/^([\w#\.\-]+)\{(.+)\}(.*)/)
        tag, attrs, text = *tag_line_contains_attr[1..3]
        "#{tag.strip} #{parse_attrs(attrs).strip} #{text.strip}".strip
      else
        tag_line.sub(/^!=/, '=')
      end
    end

    def parse_attrs(attrs, key_prefix='')
      stored_data_attributes_hash = {} # { 10001: "data-param1=true", 10002: "data-param1=false", ... }
      num_for_store = 10000

      [
        /data:\s*\{\s*([^\}]*)\s*\}/, # { data: { a: b, ... } } (Ruby 1.7 Hash Syntax)
        /:data\s*=>\s*\{([^\}]*)\s*\}/, # { :data => { :a => b, ... } }
      ].each do |regexp|
        attrs.gsub!(regexp) do
          key_with_hyphen = $1.gsub('_', '-')
          num_for_store += 1
          stored_data_attributes_hash[num_for_store] = parse_attrs(key_with_hyphen, 'data-')
          ":#{num_for_store} => #{num_for_store}"
        end
      end

      [
        /,?( ?):?('|")?([^"'{ ]+)('|")?:\s*(:?[^,]*)/, # { a: b } (Ruby 1.7 Hash Syntax)
        /,?( ?):?('|")?([^"'{ ]+)('|")?\s*=>\s*(:?[^,]*)/, # { :a => b }
      ].each do |regexp|
        attrs.gsub!(regexp) do
          space = $1
          key = $3
          value = $5.strip
          wrapped_value = (!value.match?(/['"]/) && value.include?("\s")) ? "(#{value})" : value
          wrapped_value = wrapped_value.start_with?(':') ? "\"#{wrapped_value.delete(':')}\"" : wrapped_value
          "#{space}#{key_prefix}#{key}=#{wrapped_value}"
        end
      end

      stored_data_attributes_hash.each do |num_for_store, data_attribute|
        attrs.gsub!("#{num_for_store}=#{num_for_store}", data_attribute)
      end

      attrs
    end
  end
end
