# frozen_string_literal: true

require "json"

module RSpec
  module Conductor
    module Protocol
      class Socket
        attr_reader :io

        def initialize(io)
          @io = io
        end

        def send_message(message)
          json = JSON.generate(utf8(message))
          length = [json.bytesize].pack("N")
          io.write(length)
          io.write(json.b)
          io.flush
        rescue Errno::EPIPE, IOError
          nil
        end

        def receive_message
          length_bytes = io.read(4)
          return nil unless length_bytes&.bytesize == 4

          length = length_bytes.unpack1("N")
          json = io.read(length)
          return nil unless json&.bytesize == length

          JSON.parse(json, symbolize_names: true)
        rescue Errno::ECONNRESET, IOError, JSON::ParserError
          nil
        end

        def close
          io.close unless io.closed?
        end

        private

        # json refuses ASCII-8BIT strings with non-ASCII bytes (e.g. names read from a zip or a socket)
        def utf8(value)
          case value
          when Hash then value.transform_values { |v| utf8(v) }
          when Array then value.map { |v| utf8(v) }
          when String
            value.encoding == Encoding::BINARY ? value.dup.force_encoding(Encoding::UTF_8).scrub : value
          else value
          end
        end
      end
    end
  end
end
