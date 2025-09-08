require 'date'

zshrc_location = File.expand_path("~/.zshrc")

if !File.exists?(zshrc_location)
  puts "No .zshrc file present to append."
else
  puts "Found .zshrc file to append base configuration."

  zshrc = File.open(zshrc_location, "a+")
  
  # todo -> read the file for a previously configured prompt


  zshrc.write("# --- Appending base configuration at #{Date.new.to_time.to_s} ---\n")
  zshrc.write("# ... \n")
  zshrc.write("PS1=\"%D %* %y:%d %# \"\n")
  zshrc.write("# --- End base configuration insertion ---\n")

  zshrc.flush
  zshrc.close
end

