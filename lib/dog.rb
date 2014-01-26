#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'commander/import'
require 'highline'
require 'smart_colored'
require 'rest-client'

$LOAD_PATH << "."
require_relative 'dog/state.rb'
require_relative 'dog/dog_state.rb'
require_relative 'dog/string_hacks.rb'
require_relative 'dog/version.rb'
include dog

URL = ENV["dogPAGES_URL"] || 'http://dogpages.org'
FILE = ENV["HOME"] + '/.dog'

program :name, 'dog'
program :version, dog::VERSION
program :description, "Highly readable supplement to man pages.\n\nShows simple, concise examples for commands."
default_command :lookup

state = dog::dogState.new({:file => FILE})

command :thanks do |c|
  c.syntax = 'dog thanks [COMMAND]'
  c.summary = 'Upvote an entry, dog'
  c.description = 'Upvote a dog entry. If called without a COMMAND argument, it will upvote the last thing you looked up with dog'
  c.example 'Upvote the dog entry for curl', 'dog thanks curl'
  c.action do |args, options|
    begin
      login_details = state.check_email
    rescue => e
      say "Sorry, you can't do this without email verification".sorry
      say "#{e}"
    end
    unless login_details.nil?
      cmd = state.read_state[:cmd]

      if cmd.nil?
        say "\nYou must first look up a command before downvoting. For example: dog curl\n\n".sorry
        return
      end

      idkey = args[0]
      if idkey.nil?
        idkey = "1"
      end
      id = state.read_state[idkey.intern]

      if id.nil?
        say "That id (#{idkey}) does not exist for #{cmd}, try another one".sorry
      end

      unless id.nil?
        begin
          res = RestClient.get URL + "/thanks/#{id}", { params: login_details }
        rescue => e
          say e.message
          say "There was a problem thanking the #{cmd} entry. This entry may not exist or dogpages.org may be down".problem
        else
          say "You just gave thanks to an entry for #{cmd}!".status
          say "You rock!".success
        end
      end
    end
  end
end

noblock = lambda { |c|
  c.syntax = 'dog ...no [ID]'
  c.summary = 'Downvote an entry, dog'
  c.description = 'Downvote a dog entry for the last command you looked up. If called without ID, it will downvote the top entry of the last command you looked up.'
  c.example 'Downvote the dog entry for curl', "dog curl\n\ndog ...no"
  c.action do |args, options|
    begin
      login_details = state.check_email
    rescue
      say "Sorry, you can't do this without email verification".sorry
      say "#{e}"
    end
    unless login_details.nil?

      cmd = state.read_state[:cmd]

      if cmd.nil?
        say "\nYou must first look up a command before downvoting. For example: dog curl\n\n".sorry
        return
      end

      idkey = args[0]
      if idkey.nil?
        idkey = "1"
      end
      id = state.read_state[idkey.intern]

      if id.nil?
        say "That id (#{idkey}) does not exist for #{cmd}, try another one".sorry
      end

      unless id.nil?
        begin
          res = RestClient.get URL + "/no/#{id}", { params: login_details }
        rescue => e
          say "There was a problem downvoting the #{cmd} entry. This entry may not exist or dogpages.org may be down".problem
          say e
        else
          say "You just downvoted an entry for #{cmd}".status
          say "You rock!".success
        end
      end
    end
  end
}

command :"...no", &noblock
command :no, &noblock

command :add do |c|
  c.syntax = 'dog add [COMMAND] [-m MESSAGE]'
  c.summary = 'Add an entry, dog'
  c.description = <<-QQQ.unindent
  This adds an entry to the http://dogpages.org database.
  
  Called without parameters will add an entry for the last thing you looked up with dog.
  QQQ
  c.example 'Launch your editor to add an entry for curl', 'dog add curl'
  c.example 'Quickly add an entry for curl', 'dog add curl -m "curl http://google.com"'
  # TODO c.option '-m', 'An optional inline entry. This won\'t trigger a system editor to open'
  c.action do |args, options|
    begin
      login_details = state.check_email
    rescue => e
      say "Sorry, you can't do this without email verification".sorry
      say e
    end

    unless login_details.nil?

      cmd = state.get_arg_or_last_command args

      if cmd.nil?
        say "\nYou must enter a command after #{"dog add".status}.\n\nFor example: #{"dog add".success} #{"curl".success.underline}\n\n"
      else
        prompt = <<-QQQ.unindent
          #~ dog entry for command '#{cmd}'
          #~ Provide a useful example for how to use '#{cmd}'
          #~ Comments starting with #~ are removed
          #~
          #~ Example for command 'man':
          #~ # Opens up the manual page for the command 'ls'
          #~ man ls
          
          
          # your_comment_here
          your_command_here
          QQQ
        entry = ask_editor prompt, "vim"
        if entry.gsub(prompt, '').strip.length > 0
          if agree "Submit this entry for #{cmd}? [Yn] "
            say "All right, sending your entry...".status
            begin
              res = RestClient.post URL + '/', login_details.merge({ entry: { cmd: cmd, msg: entry}, format: 'json', multipart: true })
            rescue => e
              say e.message
              file = "/tmp/#{cmd}.dog"

              # increment file name as to not overwrite anything
              i = 1
              while File.exist?(file)
                file = "/tmp/#{cmd}#{i}.dog"
                i += 1
              end

              # write message to file
              File.open(file, 'w') do |f|
                f.write entry
              end
              say "Woops. There was an error! Your entry was saved to #{file}".problem
            else
              say "Successfully submitted.".success
            end
          end
        else
          say "Canceled. Did not submit entry for '#{cmd}'".status
        end
      end
    end
  end
end

command :lookup do |c|
  c.syntax = 'dog [COMMAND]'
  c.summary = 'Lookup an entry, dog. Or just call dog [COMMAND]'
  c.description = "This looks up entries in the http://dogpages.org database."
  c.example 'Look up the dog entries for curl', 'dog curl'
  c.action do |args, options|
    if args.empty?
      say <<-QQQ.unindent
      #{"dog! Specify a command first!".colored.red}
      
      \t* For example try #{"dog curl".colored.green}
      
      \t* Use #{"dog help".colored.yellow} for more info
      
      QQQ
    else
      # the display string for the command
      cmd_display = args.join(" ")

      # the server argument for the command
      cmd = args.join("%20")

      state.reset_lookup_ids()

      # write to ~/.dog file with last command
      state.write_state({ cmd: cmd_display })

      # connect to webservice for entry
      error = false
      begin
        res = RestClient.get URL + '/' + cmd + '.json'
      rescue => e
        say <<-QQQ.unindent
        The #{cmd_display.colored.yellow} command isn't in our database.
        
        \t* Typing #{"dog add".colored.green.underline} will let you add #{cmd_display.colored.yellow} to our database!

        \t* There's nothing to lose by typing #{"dog add".colored.red.underline}, it will just launch an editor with instructions.
        
        \t* Need help? Visit #{"http://dogpages.org/help".colored.underline}
        
        QQQ
        error = true
      end

      unless error
        enable_paging
        list = JSON.parse res
        s = list.length == 1 ? 'y' : 'ies'

        say <<-QQQ.unindent
        #{"#{list.length} entr#{s} for #{cmd_display}".status.underline} #{"-- submit your own example with \"dog add #{cmd_display}\"".colored.yellow}
        
        QQQ

        sep = ""
        (HighLine::SystemExtensions.terminal_size[0] - 5).times { sep += "." }
        sep += "\n"

        i = 0
        isDefault = true
        list.each {|data|
            i += 1

            obj = {}
            obj["#{i}"] = data['id']
            state.write_state(obj)

            days = (DateTime.now - DateTime.parse(data['updated_at'])).ceil.to_i

            body = data['msg']

            body = body.gsub(/^([^#][^\n]*)$/, "\\1".important)

            say sep + "\n" if i > 1

            say body + "\n\n"

            upstr = "dog thanks"
            upstr += " #{i}" unless isDefault
            downstr = "dog ...no"
            downstr += " #{i}" unless isDefault

            msg = "\t#{upstr.colored.green}\tto upvote (#{data['up']})\n\t#{downstr.colored.red}\tto downvote (#{data['down']})"
            if days > 0
              #msg += "\tlast updated\t#{days} days ago"
            end
            say msg + "\n\n"
            isDefault = false
        }

      end
    end
  end
end
