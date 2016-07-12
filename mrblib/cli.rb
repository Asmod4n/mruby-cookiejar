def cookiemonster
  if ARGV.count != 2
    puts "Usage: #{ARGV[0]} <database>"
  end
  @monster = Cookiemonster.new(ARGV[1])

  Linenoise.completion do |buf|
    unless buf.empty?
      if buf.start_with?("register"[0...buf.bytesize])
        "register"
      elsif buf.start_with?("auth"[0...buf.bytesize])
        "auth"
      elsif buf.start_with?("get"[0...buf.bytesize])
        "get" if @cryptor
      elsif buf.start_with?("set"[0...buf.bytesize])
        "set" if @cryptor
      elsif buf.start_with?("help"[0...buf.bytesize])
        "help"
      elsif buf.start_with?("backup"[0...buf.bytesize])
        "backup"
      end
    end
  end

  Linenoise.hints do |buf|
    unless buf.empty?
      if buf.start_with?("register"[0...buf.bytesize])
        Linenoise::Hint.new("register"[buf.bytesize..-1], 35, true)
      elsif buf.start_with?("auth"[0...buf.bytesize])
        Linenoise::Hint.new("auth"[buf.bytesize..-1], 35, true)
      elsif buf.start_with?("get"[0...buf.bytesize])
        Linenoise::Hint.new("get"[buf.bytesize..-1], 35, true) if @cryptor
      elsif buf.start_with?("set"[0...buf.bytesize])
        Linenoise::Hint.new("set"[buf.bytesize..-1], 35, true) if @cryptor
      elsif buf.start_with?("help"[0...buf.bytesize])
        Linenoise::Hint.new("help"[buf.bytesize..-1], 35, true)
      elsif buf.start_with?("backup"[0...buf.bytesize])
        Linenoise::Hint.new("backup"[buf.bytesize..-1], 35, true)
      end
    end
  end

  puts "type '?' or 'help' to get help"
  while (line = linenoise("cookiemonster#{@user ? ":(#{@user})" : nil}> "))
    unless line.empty?
      if line == 'quit'||line == 'exit'
        return
      elsif line == 'help'||line == '?'
        puts "register <user> <password>\nauth <user> <password>\nset <key> <value>\nget <key>\nbackup <path>\nquit\nexit"
      elsif line.start_with?('register')
        cmd, user, password = line.split("\s", 3)
        if !user||!password
          puts "user or password missing, try 'help' or '?'"
        elsif user && user.empty?
          puts "user cannot be empty"
        elsif password && password.empty?
          puts "password cannot be empty"
        else
          begin
            @cryptor = @monster.register(user, password)
            @user = MessagePack.unpack(user.to_msgpack)
          rescue Cookiemonster::Error => e
            puts e
          end
        end
      elsif line.start_with?('auth')
        cmd, user, password = line.split("\s", 3)
        if !user||!password
          puts "user or password missing, try 'help' or '?'"
        elsif user && user.empty?
          puts "user cannot be empty"
        elsif password && password.empty?
          puts "password cannot be empty"
        else
          begin
            @cryptor = @monster.auth(user, password)
            @user = MessagePack.unpack(user.to_msgpack)
          rescue Crypto::Error, Cookiemonster::Error => e
            puts "Cannot log you in"
          end
        end
      elsif line.start_with?('set')
        unless @cryptor
          puts "Not logged in"
          next
        end
        cmd, key, value = line.split("\s", 3)
        if !key||!value
          puts "key or value missing, try 'help' or '?'"
        elsif key && key.empty?
          puts "key cannot be empty"
        elsif value && value.empty?
          puts "value cannot be empty"
        else
          @cryptor[key] = value
        end
      elsif line.start_with?('get')
        unless @cryptor
          puts "Not logged in"
          next
        end
        cmd, key = line.split("\s", 2)
        if !key
          puts "key missing, try 'help' or '?'"
        elsif key && key.empty?
          puts "key cannot be empty"
        else
          value = @cryptor[key]
          if value
            puts value
            Sodium.memzero(value, value.bytesize)
          end
        end
      elsif line.start_with?('backup')
        cmd, path = line.split("\s", 2)
        if !path
          puts "path missing"
        elsif path.empty?
          puts "path missing"
        else
          @monster.backup(path)
        end
      else
        puts "Unknown command, try 'help' or '?"
      end
      Sodium.memzero(line, line.bytesize)
    end
  end
end
