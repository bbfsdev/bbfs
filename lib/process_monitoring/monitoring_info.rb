module BBFS
  module MonitoringInfo
    class MonitoringInfo
      #def self.get_html(clientsCol)
      #clientsCol.inspect
      def self.get_html (hash, opts = {})
        return if !hash.is_a?(Hash)

        indent_level = opts.fetch(:indent_level) { 0 }

        out = " " * indent_level + "<ul>\n"

        hash.each do |key, value|
          out += " " * (indent_level + 2) + "<li><strong>#{key}:</strong>"

          if value.is_a?(Hash)
            out += "\n" + get_html(value, :indent_level => indent_level + 2) + " " * (indent_level + 2) + "</li>\n"
          else
            out += " <span>#{value}</span></li>\n"
          end
        end

        out += " " * indent_level + "</ul>\n"

      end
    end
  end
end