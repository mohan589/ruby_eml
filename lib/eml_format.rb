require 'mimemagic'
require 'base64'
require 'fileutils'
require 'byebug'
require 'securerandom'

class EmlFormat
  END_OF_LINE = "\r\n".freeze

  def initialize
    @verbose = false
    @default_charset = 'utf-8'
  end

  def guid
    SecureRandom.uuid
  end

  # Gets file extension by mime type
  def get_file_extension(mime_type)
    '.' + MimeMagic.new(mime_type).extensions.first || ''
  end

  # Gets the boundary name
  def get_boundary(content_type)
    boundary = content_type.match(/^boundary="?(.+?)"?(\s*;[\s\S]*)?$/)
    boundary ? boundary[1] : nil
  end

  # Gets character set name, e.g. contentType='.....charset="iso-8859-2"....'
  def get_char_set(content_type)
    char_set = content_type.match(/charset\s*=\W*([\w\-]+)/)
    char_set ? boundary[1] : nil
  end

  def get_charset_name(charset)
    charset.downcase.match(/[^0-9a-z]/, "")
  end

  # Gets name and e-mail address from a string, e.g. "PayPal" <noreply@paypal.com> => { name: "PayPal", email: "noreply@paypal.com" }
  def get_email_address(raw)
    list = []
    parts = raw.match(/("[^"]*")|[^,]+/)

    parts.each do |ele|
      address = OpenStruct.new

      # Quoted name but without the e-mail address - TODO

      regex = /^(.*?)(\s*<(.*?)>)$/
      match = regex.match(parts[i])

      if match
        name = unquote_string(ele).replace(/"/, '').strip
        address.name = name if name
        address.email = match[3].strip
        list.push(address)
      else
        address.email = ele.strip
        list.push(address)
      end

      return nil if list.empty?
      return list[0] if list.length == 1
    end

    list
  end

  def to_email_address(data)
    return if data.nil?

    email = ''
    if data.instance_of?(String)
      email = data
    elsif data.instance_of?(Array)
      data.each do |ele|
        email += email.length > 0 ? ', ' : ''
        email += '"' + ele.dig(:name) + '"' if ele.dig(:name)
        email += (email.length > 0 ? ' ' : '') + '<' + ele.dig(:email) + '>' if ele.dig(:email)
      end
    else
      email += '"' + data.dig(:name) + '"' if data.dig(:name)
      email += (email.length > 0 ? ' ' : '') + '<' + data.dig(:email) + '>' if data.dig(:email)
    end
    email
  end

  def unquote_string(s)
    regex = /=\?([^?]+)\?(B|Q)\?(.+?)(\?=)/
    match = regex.match(s)

    if match
      charset = get_charset_name(match[1] || @default_charset)
      type = match[2].upcase
      value = match[3]

      if type == 'B'
        if charset == @default_charset
          regex_value = value.gsub(/\r?\n/, '')
          return Base64.decode64(regex_value).force_encoding('UTF-8')
        end
      elsif type == 'Q'
        return unquote_printable(value, charset)
      end
    end
    s
  end

  def unquote_printable(value, charset); end

  def unqoute_utf8(s)
    # regex = /=\?UTF-8\?(B|Q)\?(.+?)(\?=)/
    # match = regex.scan(s)
    # if match
    #   type = match[1].upcase
    #   value = match[2]
    #   if type == 'B'
    #     regex_value = value.gsub(/\r?\n/, '')
    #     Base64.decode64(regex_value).force_encoding('UTF-8')
    #   elsif type == 'Q'
    #     unquote_printable(value, charset)
    #   end
    # end
  end

  def unpack(_eml, directory, options, callback)
    # result = { files: [] }
    # FileUtils.mkdir_p directory unless Dir.exist?(directory)

    # proc = proc do |data|
    #   if data.try(:text).instance_of?(String)
    #     result[:files].push('index.txt')
    #     File.write(directory + '/index.txt', data.try(:text)) unless options
    #   end

    #   if data.try(:html).instance_of?(String)
    #     result[:files].push('index.txt')
    #     File.write(directory + '/index.txt', data.try(:html)) unless options
    #   end

    #   if data.try(:attachments) && data.try(:attachments).length
    #     attachments.each_with_index do |attachment|
    #       filename = attachment.name
    #       unless filename
    #         filename = 'attachment_' + index.to_s + get_file_extension(attachment.mime_type)
    #       end
    #       result[:files].push(filename)
    #       # if (options && options.simulate) continue; //Skip writing to file
    #       File.write(directory + filename, attachment.try(:data))
    #     end
    #   end
    # rescue StandardError
    #   puts "error"
    # end
    # callback.call(result)
  end

  #  Unpacks EML message and attachments to a directory.
  #  * @params eml         EML file content or object from 'parse'
  #  * @params directory   Folder name or directory path where to unpack
  #  * @params options     Optional parameters: { parsedJsonFile, readJsonFile, simulate }
  #  * @params callback    Callback function(error)

  def build(data:, options: nil, callback: nil)
    data.transform_keys!
    callback ||= options

    eml = ''

    begin
      raise "Agrument 'data' exepected to be an object" if !data || data.class != Hash

      data[:headers] = {} if data && !data.key?(:headers)

      data[:headers][:subject] = data.dig(:subject) if data.dig(:subject) && data.dig(:subject).instance_of?(String)

      %i[from to cc].each do |key, _value|
        data[:headers][key] = data.dig(key).instance_of?(String) ? data.dig(key) : to_email_address(data.dig(key))
      end

      raise "Missing 'To' e-mail address!" unless data.dig(:headers, :to)

      boundary = '----=' + guid

      if !data.dig(:headers)['Content-Type']
        data[:headers]['Content-Type'] = "multipart/mixed\;" + END_OF_LINE + 'boundary="' + boundary + '"'
      else
        name = get_boundary(data.dig(:headers)['Content-Type'])
        boundary = name if name
      end
      keys = (data[:headers].keys << data.keys).flatten.uniq

      keys.each do |key|
        value = data.dig(:headers, key)
        if !value
          next
        elsif value.instance_of?(String)

          eml += key.to_s + ': ' + value.gsub(/\r?\n/, END_OF_LINE + '  ') + END_OF_LINE
        else

          value.each do |j|
            eml += key.to_s + ': ' + value[j].gsub(/\r?\n/, END_OF_LINE + '  ') + END_OF_LINE
          end
        end
      end

      # Start the body
      eml += END_OF_LINE
      if data.dig(:text)
        eml += '--' + boundary + END_OF_LINE
        eml += 'Content-Type: text/plain; charset=utf-8' + END_OF_LINE
        eml += END_OF_LINE
        eml += data.dig(:text)
        eml += END_OF_LINE + END_OF_LINE
      end

      if data.dig(:html)
        eml += '--' + boundary + END_OF_LINE
        eml += 'Content-Type: text/html; charset=utf-8' + END_OF_LINE
        eml += END_OF_LINE
        eml += data.dig(:html)
        eml += END_OF_LINE + END_OF_LINE
      end

      if data.dig(:attachments)
        data.dig(:attachments).each_with_index do |attachment, index|
          eml += '--' + boundary + END_OF_LINE
          eml += 'Content-Type: ' + (attachment['Content-Type'] || 'application/octet-stream') + END_OF_LINE
          eml += 'Content-Transfer-Encoding: base64' + END_OF_LINE
          eml += 'Content-Disposition: ' + (attachment.dig(:inline) ? 'inline' : 'attachment') + '; filename="' + (attachment.dig(:filename) || attachment.dig(:name) || ('attachment_' + (index + 1))) + '"' + END_OF_LINE
          eml += 'Content-ID: <' + attachment.cid + '>' + END_OF_LINE if attachment.dig(:cid)
          eml += END_OF_LINE
          content = Base64.encode64(attachment.dig(:data))
          eml += content + END_OF_LINE
          eml += END_OF_LINE
        end
      end
      eml += '--' + boundary + '--' + END_OF_LINE

      callback&.call(eml)
    rescue StandardError => e
      puts e
    ensure
      puts 'Done!'
    end
  end

  # Appends the boundary to the result
  def append_boundary(headers, content)
    content_type = headers.dig(:content_type)
    charset = get_charset_name(get_char_set(content_type || @default_charset))
    encoding = headers.dig("Content-Transfer-Encoding")

    if encoding.instance_of? (String)
      encoding = encoding.downcase
    end

    if encoding.instance_of?(Base64)
      if content_type.index "gbk"
        content = Base64.decode64(content)
      else
        content = Base64.decode64(content.gsub(/\r?\n/, ''))
      end
    elsif encoding == 'quoted-printable'
      content = unquote_printable(content, charset)
    elsif charset != "utf8" && ((encoding.start_with? ("binary")) || (encoding.start_with? ("8bit")))
      content = Base64.decode64(content, charset)
    end

    if !result.dig(:html) && content_type && (content_type.index "text/html")
      if content.instance_of? (String)
        content = Base64.decode64(content, charset)
      end
      result[:html] = content
    elsif !result.dig(:text) && content_type && (content_type.index "text/plain")
      if content.instance_of? (String)
        content = Base64.decode64(content, charset)
      end
      result[:text] = content
    else
      if !result.attachment
        result[:attachments] = []
      end

      attachment = {}

      id = headers.dig("Content-ID")
      if id
        attachment[:id] = id
      end

      name = headers["Content-Disposition"] || headers["Content-Type"]

      if name
        match = name.match(/name="?(.+?)"?$/)
        if match
          name = match[1]
        else
          name = nil
        end
      end

      if name
        attachment[:name] = name
      end

      ct = headers["Content-Type"]

      if ct
        attachment[:content_type] = ct
      end

      cd = headers["Content-Disposition"]

      if cd
        attachment[:inline] = cd.match(/^\s*inline/)
      end

      attachment[:data] = content
      result[:attachments].push(attachment)
    end
    result
  end

  # ******************************************************************************************
  #  Parses EML file content and return user-friendly object.
  #  @params eml         EML file content or object from 'parse'
  #  @params options     EML parse options
  #  @params callback    Callback function(error, data)
  # ******************************************************************************************
  def read(data:, options: nil, callback: nil)
    parsed_data = parse(eml: data, options: options, callback: callback)

    begin
      result = {}
      result[:date] = new Date(data.dig(:headers)) if data.dig(:headers, 'Date')
      # byebug
      result[:subject] = unquote_string(data.dig(:headers, :subject)) if data.dig(:subject)

      %i[from to CC cc].each do |item|
        result[item] = get_email_address(data.dig(:headers, item))
      end

      result[:headers] = data.dig(:headers)

      boundary = nil

      ct = data.dig(:headers, 'Content-Type')
      # byebug
      if ct && ct.match(/^multipart\//)
        b = get_boundary(ct)
        if b && b.length
          boundary = b
        end
      end

      if boundary
        for body_data in data.dig(:body)
          if body_data.dig(:part).instance_of? (String)
            result[:data] = body_data[:part]
          else
            if body_data.dig(:part, :body).instance_of? (String)
              headers = body_data.dig(:part, :headers)
              content = body_data.dig(:part, :body)
              append_boundary(headers, content)
            else
              for item in body_data.dig(:part, :body) do
                if item.instance_of?(String)
                  result[:data] = body_data.dig(:part, :body)[item]
                  next
                end

                headers = body_data.dig(:part, :body, item, :part, :headers)
                content = body_data.dig(:part, :body, item, :part, :body)

                append_boundary(headers, content)
              end
            end
          end
        end
      elsif data.dig(:body).instance_of?(String)
        append_boundary(data.dig(:headers), data.dig(body))
      end
      callback.call(result)
    rescue StandardError => e
    end
  end

  #  ******************************************************************************************
  #  * Parses EML file content and returns object-oriented representation of the content.
  #  * @params eml         EML file content
  #  * @params options     EML parse options
  #  * @params callback    Callback function(error, data)
  #  ******************************************************************************************
  def parse(eml:, options: nil, callback: nil)
    # sub_data = eml.gsub!(/\r\n?/, "")
    # byebug
    lines = eml
    # lines = File.readlines('sample.eml')
    # byebug
    result = {}
    parse_recursively(lines, 0, result, options)

    callback.call(result)
  rescue StandardError => e
    print e
  ensure
    print 'Done !'
  end

  def complete(boundary)
    boundary[:part] = {}
    parse_recursively(boundary[:lines], 0, boundary[:part], options)
    boundary.tap { |x| x.delete(:lines) }
  end

  def parse_recursively(lines, _start, parent, options)
    boundary = nil
    last_header_name = ''
    find_boundary = ''
    is_inside_body = false
    is_inside_boundary = false
    is_multi_header = false
    is_multi_part = false

    parent[:headers] = {}
    lines.each_with_index do |line, index|
      # Header
      if !is_inside_body
        puts "insideBody"
        # Search for empty line
        if line.empty?
          is_inside_body = true
          break if options && options[:headers_only]

          # Expected boundary
          ct = parent[:headers]['Content-Type']
          if ct && ct.match(/^multipart\//)
            b = get_boundary(ct)
            if b && b.size
              find_boundary = b
              is_multi_part = true
              parent[:body] = []
            end
          elsif @verbose
            puts 'Multipart without boundary! ' + ct.gsub(/\r?\n/, ' ')
          end
          next
        end

        # Header value with new line
        match = /^\s+([^\n]+)/.match(line)&.string
        puts "line" + line + "   " + match.to_s
        if match
          if is_multi_header
            parent[:headers][last_header_name][parent[:headers][last_header_name]&.length - 1] += "\r\n" + match[1]
          else
            parent[:headers][last_header_name] += "\r\n" + match[1]
          end
          next
        end

        # Header name and value
        match = line.match(/^([\w\d\-]+):\s+([^\r\n]+)/)
        if match
          last_header_name = match[1]
          if parent[:headers][last_header_name]
            is_multi_header = true

            if parent[:headers][last_header_name].instance_of?(String)
              parent[:headers][last_header_name] = [parent[:headers][last_header_name]]
            end
            parent[:headers][last_header_name].push(match[2])
          else
            # Header first appeared here
            is_multi_header = false
            parent[:headers][last_header_name] = match[2]
          end
        end
      # Body
      elsif is_multi_part
        puts "inside multipart"
        # Multipart body
        if line.indexOf('--' + findBoundary) == 0 && !line.match(/--(\r?\n)?$/)
          is_inside_boundary = true

          complete(boundary) if boundary && boundary[:lines]

          match = line.match(/^--([^\r\n]+)(\r?\n)?$/)
          boundary = { boundary: match[1], lines: [] }
          parent[:body].push(boundary)

          puts 'Found boundary: ' + boundary.boundary if @verbose
          next
        end

        if is_inside_boundary
          if boundary[:boundary] && line.indexOf('--' + findBoundary + '--') == 0
            is_inside_boundary = false
            complete(boundary)
            next
          end
          boundary[:boundary].push(line)
        end
      # Search for boundary start
      else
        # Solid string body
        parent[:body] = lines.slice(index, line.length - 1).join("\r\n")
        break
      end

      if parent.dig(:body) && parent.dig(:body).size && parent.dig(:body)[parent.dig(:body).length - 1][:lines]
        complete(parent.dig(:body)[parent.dig(:body).length - 1])
      end
    end
  end

  attr_accessor :verbose, :file_extensions, :default_charset
end
