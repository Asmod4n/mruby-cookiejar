def cookiemonster
  if ARGV.count != 2
    puts "Usage: #{ARGV[0]} <database>"
    return
  end
  @monster = Cookiemonster.new(ARGV[1])
  if @monster.empty?
    puts "Add your first user"
  end

  tried = 0

  while tried < 3
    user = linenoise("login:")
    if @monster.empty?
      password = Cookiemonster.getpass("Enter new password:")
    else
      password = Cookiemonster.getpass
    end
    if !user||!password
      return
    end
    if @monster.empty?
      unless password == Cookiemonster.getpass("Retype new password:")
        puts "Passwords don't macth\n\n"
        tried += 1
        next
      end
    end
    if user && user.empty?
      puts "Login incorrect\n\n"
      tried += 1
      next
    end
    if password && password.empty?
      puts "Login incorrect\n\n"
      tried += 1
      next
    end
    begin
      if @monster.empty?
        @cryptor = @monster.useradd(user, password)
      else
        @cryptor = @monster.login(user, password)
      end
      @user = MessagePack.unpack(user.to_msgpack)
      break
    rescue Cookiemonster::PasswordError => e
      tried += 1
      puts "#{e.class}: #{e}\n\n"
    rescue Cookiemonster::Error, Crypto::Error
      tried += 1
      puts "Login incorrect\n\n"
    end
  end

  if tried == 3
    return
  end

  Linenoise.completion do |buf|
    unless buf.empty?
      if buf.start_with?("useradd"[0...buf.bytesize])
        "useradd"
      elsif buf.start_with?("login"[0...buf.bytesize])
        "login"
      elsif buf.start_with?("get"[0...buf.bytesize])
        "get"
      elsif buf.start_with?("set"[0...buf.bytesize])
        "set"
      elsif buf.start_with?("help"[0...buf.bytesize])
        "help"
      elsif buf.start_with?("backup"[0...buf.bytesize])
        "backup"
      elsif buf.start_with?("cls"[0...buf.bytesize])
        "cls"
      elsif buf.start_with?("quit"[0...buf.bytesize])
        "quit"
      elsif buf.start_with?("exit"[0...buf.bytesize])
        "exit"
      end
    end
  end

  Linenoise.hints do |buf|
    unless buf.empty?
      if buf.start_with?("useradd"[0...buf.bytesize])
        Linenoise::Hint.new("useradd"[buf.bytesize..-1], 35, true)
      elsif buf.start_with?("login"[0...buf.bytesize])
        Linenoise::Hint.new("login"[buf.bytesize..-1], 35, true)
      elsif buf.start_with?("get"[0...buf.bytesize])
        Linenoise::Hint.new("get"[buf.bytesize..-1], 35, true)
      elsif buf.start_with?("set"[0...buf.bytesize])
        Linenoise::Hint.new("set"[buf.bytesize..-1], 35, true)
      elsif buf.start_with?("help"[0...buf.bytesize])
        Linenoise::Hint.new("help"[buf.bytesize..-1], 35, true)
      elsif buf.start_with?("backup"[0...buf.bytesize])
        Linenoise::Hint.new("backup"[buf.bytesize..-1], 35, true)
      elsif buf.start_with?("cls"[0...buf.bytesize])
        Linenoise::Hint.new("cls"[buf.bytesize..-1], 35, true)
      elsif buf.start_with?("exit"[0...buf.bytesize])
        Linenoise::Hint.new("exit"[buf.bytesize..-1], 35, true)
      elsif buf.start_with?("quit"[0...buf.bytesize])
        Linenoise::Hint.new("quit"[buf.bytesize..-1], 35, true)
      end
    end
  end

  puts "type '?' or 'help' to get help"
  while (line = linenoise("cookiemonster#{@user ? ":(#{@user})" : nil}> "))
    unless line.empty?
      if line == 'quit'||line == 'exit'
        return
      elsif line == 'help'||line == '?'
        puts "useradd <username>\nlogin <username>\nset <key> <value>\nget <key>\nbackup <path>\nquit\nexit\ncls clears the screen"
      elsif line == 'cls'
        Linenoise.clear_screen
      elsif line.start_with?("useradd")
        cmd, username = line.split("\s", 2)
        if !username
          puts "username missing, try 'help' or '?'"
        elsif username && username.empty?
          puts "username cannot be empty"
        else
          password = Cookiemonster.getpass("Enter new password:")
          unless password == Cookiemonster.getpass("Retype new password:")
            puts "Passwords don't match"
            next
          end
          begin
            @monster.useradd(username, password)
          rescue Cookiemonster::Error => e
            puts "#{e.class}: #{e}"
          end
        end
      elsif line.start_with?('login')
        cmd, username = line.split("\s", 2)
        if !username
          puts "username missing, try 'help' or '?'"
        elsif username && username.empty?
          puts "username cannot be empty"
        else
          password = Cookiemonster.getpass
          if !password
            puts "password missing, try 'help' or '?'"
          elsif password && password.empty?
            puts "password cannot be empty"
          else
            begin
              @cryptor = @monster.login(username, password)
              @user = MessagePack.unpack(username.to_msgpack)
            rescue Cookiemonster::Error, Crypto::Error
              puts "Login incorrect"
            end
          end
        end
      elsif line.start_with?('set')
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
