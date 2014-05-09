#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Cauldron.Status do
  def to_string(100), do: "Continue"
  def to_string(101), do: "Switching Protocols"
  def to_string(102), do: "Processing"
  def to_string(200), do: "OK"
  def to_string(201), do: "Created"
  def to_string(202), do: "Accepted"
  def to_string(203), do: "Non-Authoritative Information"
  def to_string(204), do: "No Content"
  def to_string(205), do: "Reset Content"
  def to_string(206), do: "Partial Content"
  def to_string(207), do: "Multi-Status"
  def to_string(226), do: "IM Used"
  def to_string(300), do: "Multiple Choices"
  def to_string(301), do: "Moved Permanently"
  def to_string(302), do: "Found"
  def to_string(303), do: "See Other"
  def to_string(304), do: "Not Modified"
  def to_string(305), do: "Use Proxy"
  def to_string(306), do: "Switch Proxy"
  def to_string(307), do: "Temporary Redirect"
  def to_string(400), do: "Bad Request"
  def to_string(401), do: "Unauthorized"
  def to_string(402), do: "Payment Required"
  def to_string(403), do: "Forbidden"
  def to_string(404), do: "Not Found"
  def to_string(405), do: "Method Not Allowed"
  def to_string(406), do: "Not Acceptable"
  def to_string(407), do: "Proxy Authentication Required"
  def to_string(408), do: "Request Timeout"
  def to_string(409), do: "Conflict"
  def to_string(410), do: "Gone"
  def to_string(411), do: "Length Required"
  def to_string(412), do: "Precondition Failed"
  def to_string(413), do: "Request Entity Too Large"
  def to_string(414), do: "Request-URI Too Long"
  def to_string(415), do: "Unsupported Media Type"
  def to_string(416), do: "Requested Range Not Satisfiable"
  def to_string(417), do: "Expectation Failed"
  def to_string(418), do: "I'm a teapot"
  def to_string(422), do: "Unprocessable Entity"
  def to_string(423), do: "Locked"
  def to_string(424), do: "Failed Dependency"
  def to_string(425), do: "Unordered Collection"
  def to_string(426), do: "Upgrade Required"
  def to_string(428), do: "Precondition Required"
  def to_string(429), do: "Too Many Requests"
  def to_string(431), do: "Request Header Fields Too Large"
  def to_string(500), do: "Internal Server Error"
  def to_string(501), do: "Not Implemented"
  def to_string(502), do: "Bad Gateway"
  def to_string(503), do: "Service Unavailable"
  def to_string(504), do: "Gateway Timeout"
  def to_string(505), do: "HTTP Version Not Supported"
  def to_string(506), do: "Variant Also Negotiates"
  def to_string(507), do: "Insufficient Storage"
  def to_string(510), do: "Not Extended"
  def to_string(511), do: "Network Authentication Required"

  def to_integer("Continue"),                        do: 100
  def to_integer("Switching Protocols"),             do: 101
  def to_integer("Processing"),                      do: 102
  def to_integer("OK"),                              do: 200
  def to_integer("Created"),                         do: 201
  def to_integer("Accepted"),                        do: 202
  def to_integer("Non-Authoritative Information"),   do: 203
  def to_integer("No Content"),                      do: 204
  def to_integer("Reset Content"),                   do: 205
  def to_integer("Partial Content"),                 do: 206
  def to_integer("Multi-Status"),                    do: 207
  def to_integer("IM Used"),                         do: 226
  def to_integer("Multiple Choices"),                do: 300
  def to_integer("Moved Permanently"),               do: 301
  def to_integer("Found"),                           do: 302
  def to_integer("See Other"),                       do: 303
  def to_integer("Not Modified"),                    do: 304
  def to_integer("Use Proxy"),                       do: 305
  def to_integer("Switch Proxy"),                    do: 306
  def to_integer("Temporary Redirect"),              do: 307
  def to_integer("Bad Request"),                     do: 400
  def to_integer("Unauthorized"),                    do: 401
  def to_integer("Payment Required"),                do: 402
  def to_integer("Forbidden"),                       do: 403
  def to_integer("Not Found"),                       do: 404
  def to_integer("Method Not Allowed"),              do: 405
  def to_integer("Not Acceptable"),                  do: 406
  def to_integer("Proxy Authentication Required"),   do: 407
  def to_integer("Request Timeout"),                 do: 408
  def to_integer("Conflict"),                        do: 409
  def to_integer("Gone"),                            do: 410
  def to_integer("Length Required"),                 do: 411
  def to_integer("Precondition Failed"),             do: 412
  def to_integer("Request Entity Too Large"),        do: 413
  def to_integer("Request-URI Too Long"),            do: 414
  def to_integer("Unsupported Media Type"),          do: 415
  def to_integer("Requested Range Not Satisfiable"), do: 416
  def to_integer("Expectation Failed"),              do: 417
  def to_integer("I'm a teapot"),                    do: 418
  def to_integer("Unprocessable Entity"),            do: 422
  def to_integer("Locked"),                          do: 423
  def to_integer("Failed Dependency"),               do: 424
  def to_integer("Unordered Collection"),            do: 425
  def to_integer("Upgrade Required"),                do: 426
  def to_integer("Precondition Required"),           do: 428
  def to_integer("Too Many Requests"),               do: 429
  def to_integer("Request Header Fields Too Large"), do: 431
  def to_integer("Internal Server Error"),           do: 500
  def to_integer("Not Implemented"),                 do: 501
  def to_integer("Bad Gateway"),                     do: 502
  def to_integer("Service Unavailable"),             do: 503
  def to_integer("Gateway Timeout"),                 do: 504
  def to_integer("HTTP Version Not Supported"),      do: 505
  def to_integer("Variant Also Negotiates"),         do: 506
  def to_integer("Insufficient Storage"),            do: 507
  def to_integer("Not Extended"),                    do: 510
  def to_integer("Network Authentication Required"), do: 511
end
