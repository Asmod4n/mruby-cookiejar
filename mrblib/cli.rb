def cookiemonster
  if ARGV.count != 2
    puts "Usage: #{ARGV[0]} <database>"
    return
  end
  @monster = Cookiemonster.new(ARGV[1])
  if @monster.empty?
    puts "Register your first user"
  end

  tried = 0

  while tried < 3
    user = linenoise("Username:")
    password = Cookiemonster.getpass
    if @monster.empty?
      unless password.securecmp(Cookiemonster.getpass("Retype Password:"))
        puts "Passwords don't macth\n\n"
        tried += 1
        next
      end
    end
    if user && user.empty?
      puts "Username cannot be empty\n\n"
      tried += 1
      next
    end
    if password && password.empty?
      puts "Password cannot be empty\n\n"
      tried += 1
      next
    end
    begin
      if @monster.empty?
        @cryptor = @monster.register(user, password)
      else
        @cryptor = @monster.auth(user, password)
      end
      @user = MessagePack.unpack(user.to_msgpack)
      break
    rescue Cookiemonster::Error => e
      tried += 1
      puts "#{e.class}: #{e}\n"
      next
    end
  end

  if tried == 3
    return
  end

  Linenoise.completion do |buf|
    unless buf.empty?
      if buf.start_with?("get"[0...buf.bytesize])
        "get" if @cryptor
      elsif buf.start_with?("set"[0...buf.bytesize])
        "set" if @cryptor
      elsif buf.start_with?("help"[0...buf.bytesize])
        "help"
      elsif buf.start_with?("backup"[0...buf.bytesize])
        "backup"
      elsif buf.start_with?("cls"[0...buf.bytesize])
        "cls"
      end
    end
  end

  Linenoise.hints do |buf|
    unless buf.empty?
      if buf.start_with?("get"[0...buf.bytesize])
        Linenoise::Hint.new("get"[buf.bytesize..-1], 35, true) if @cryptor
      elsif buf.start_with?("set"[0...buf.bytesize])
        Linenoise::Hint.new("set"[buf.bytesize..-1], 35, true) if @cryptor
      elsif buf.start_with?("help"[0...buf.bytesize])
        Linenoise::Hint.new("help"[buf.bytesize..-1], 35, true)
      elsif buf.start_with?("backup"[0...buf.bytesize])
        Linenoise::Hint.new("backup"[buf.bytesize..-1], 35, true)
      elsif buf.start_with?("cls"[0...buf.bytesize])
        Linenoise::Hint.new("cls"[buf.bytesize..-1], 35, true)
      end
    end
  end

  puts "type '?' or 'help' to get help"
  while (line = linenoise("cookiemonster#{@user ? ":(#{@user})" : nil}> "))
    unless line.empty?
      if line == 'quit'||line == 'exit'
        return
      elsif line == 'help'||line == '?'
        puts "set <key> <value>\nget <key>\nbackup <path>\nquit\nexit\ncls clears the screen"
      elsif line == 'cls'
        Linenoise.clear_screen
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
          puts "path cannot be empty"
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
