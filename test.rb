load 'lib/eml_format.rb'

data = {
  from: "no-reply@bar.com",
  to: [ 
    { name: "Foo", email: "foo@example.com" },
    { name: "Bar", email: "bar@example.com" }
  ],
  cc: [
    { name: "Foo Bar", email: "foo@bar.com" },
    { email: "info@bar.com" }
  ],
  subject: "Winter promotions",
  text: "Lorem ipsum...",
  html: '<!DOCTYPE html><html><head><meta http-equiv="Content-Type"  content="message/rfc822" /><meta name="viewport" content="width=device-width, initial-scale=1.0"/></head><body>Lorem ipsum...<br /><img src="nodejs.png" alt="" /></body></html>',
  attachments: [
      {
      name: "sample.txt",
      contentType: "text/plain; charset=utf-8",
      data: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi eget elit turpis. Aliquam lorem nunc, dignissim in risus at, tempus aliquet justo..."
    },
    {
      name: "nodejs.png",
      contentType: "image/png",
      data: File.open("nodejs.png").read,
      inline: true
    }
  ]
}

proc = Proc.new {|data|
    File.open("sample.eml", 'w') { |file| file.write(data) }
}

EmlFormat.new.build(data: data, options: nil, callback: proc)