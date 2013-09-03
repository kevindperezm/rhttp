# rhttp - Simple Web Server.
# Simple servidor http programado en Ruby.
# Tal vez haga mi tesis con esto :D

require 'socket'

class rhttpServer
	def initialize(rootdir, port) 
		@rootdir = rootdir
		@port = port
	end

	def start
		serversocket = TCPServer.open(@port)
			loop do
				clientsocket = serversocket.accept
				Thread.new do
					puts "\r\nClient connected :)"
					puts "Launching worker for him..."
					rhttpWorker.new(@rootdir, clientsocket).start
					 # Worker despacha la petición
				end
			end
		serversocket.close
	end
end

class rhttpWorker
	def initialize(rootdir, socket)
		@rootdir = rootdir
		@socket = socket
	end

	def start
		begin
			# Obteniendo petición 
			request = @socket.gets
			#puts request
			puts "INCOMING REQUEST"
			# Descomponiendo petición 
			if request != nil
				reqtype, reqresource, reqprotocol = request.split(" ")
				# Identificando query string
				reqresource, querystring = reqresource.split("?")

				puts "Request type is "+reqtype
				puts "Requested resource is "+reqresource

			end

			# Tipo de petición 
			case reqtype
			when "GET"
				# Buscando el archivo solicitado
				# Cambiando el nombre del recurso raíz
				if reqresource == "/"
					reqresource = "/index.php"
					if File.exist?(@rootdir+"/index.html")
						reqresource = "/index.html"
					end
				end

				@html = "" # Reiniciando @html
				@response = "" # Reiniciando @response
				# Abriendo el recurso
				if File.exist?(@rootdir+reqresource)
					# Identificando el Content-Type por extensión del
					# recurso.
					# TODO: Mejor método. Este método es poco fiable.
					is_php = false
					ext = reqresource.split(".").last
					case ext
					when "jpg"
						ctype = "image/jpeg"
					when "png"
						ctype = "image/png"
					when "gif"
						ctype = "image/gif"
					when "js"
						ctype = "text/javascript"
					when "css"
						ctype = "text/css"
					when "html"
						ctype = "text/html"
					when "php"
						# ctype es determinado por lo que devuelva php-cgi
						is_php = true
					end

					if is_php
						# Preprocesando el PHP para enviar la salida como HTML
						puts "Preprocessing PHP resource..."
						# Preparando el entorno para ejecutar php-cgi
						ENV['REDIRECT_STATUS'] = "200" # Necesaria para ejecutar php-cgi
						ENV['SCRIPT_FILENAME'] = @rootdir+reqresource
						ENV['QUERY_STRING'] = querystring
						ENV['REQUEST_METHOD'] = reqtype
						# Lanzando php-cgi
						output = ""
						IO.popen("php-cgi") do |pipe|
							while line = pipe.gets
								if line.start_with?("Content-type: ")
									ctype = line
								end
								output += line
							end
						end	
						ctype = ctype.split(": ").last.chomp
						@html = output.split(ctype).last					

					else
						# Leyendo el contenido sin preprocesar
						res = File.open(@rootdir+reqresource, "r") do |file|  	
							while line = file.gets
								@html += line
							end
						end
						puts "Loaded content of resource"
					end

					size = (@html.size*8).to_s

					@response =  "HTTP/1.1 200 OK\r\n"
					@response += "Server: rhttp 0.1 (Linux Mint)\r\n"
					@response += "Content-Type: #{ctype}\r\n"
					@response += "Content-Length: #{size}\r\n"

				else
					puts "Resource not found"
					@response = "HTTP/1.1 404 NOT FOUND\r\n"
					@response += "Server: rhttp 0.1 (Linux Mint)\r\n"
					@html = "<html>
					<head>
					<title>404 Not Found</title>
					</head>
					<body>
					<h1>Sorry :(</h1>
						The requested resource '#{reqresource}' was not found.<br/>
						Check for typos.<br/>
						<hr/>
						<h6>rhttp 1.0 (Linux Mint)</h6>
						</body>
						</html>"
					end
				end
			# Enviando datos
			@socket.puts(@response+"\r\n"+@html)
			puts "Response sent"
			puts "Worker. Change and Out. *TKKK*"
			@socket.close

		rescue Exception => e
			puts "Exception: "
			puts e.message
			puts e.backtrace.inspect
		ensure
			@socket.close		
		end
	end
end

# Punto de entrada

#puts "Bienvenido a rhttp ;D"
print "Número de puerto: "
port = gets.chomp
#puts "Iniciando servidor..."
server = rhttpServer.new("www", port)
server.start