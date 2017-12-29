# coding: utf-8
module Okubi
  module CLI
    module Utils
      module UserInterface
        # TTY Helpers #
        def pastel
          @pastel ||= Pastel.new
        end
        def prompt
          @prompt ||= TTY::Prompt.new
        end
        def shell
          @shell ||= TTY::Command.new(dry_run: false, printer: :null)
        end
        def shell_out
          @shell_out ||= TTY::Command.new(dry_run: false)
        end

        # Colorized Notices #
        def put_info(text)
          puts "%s %s" % [pastel.blue.bold("[INFO]"), text]
        end
        def put_task(text)
          puts "%s %s" % [pastel.cyan.bold("[TASK]"), pastel.bold(text)]
        end
        def put_warning(text)
          puts "%s %s" % [pastel.yellow.bold("[WARNING]"), pastel.bold(text)]
        end
        def put_error(text)
          puts "%s %s" % [pastel.red.bold("[ERROR]"), pastel.bold(text)]
        end
        def put_success(text)
          puts "%s %s" % [pastel.green.bold("[SUCCESS]"), pastel.bold(text)]
        end
        def put_command(text)
          puts "%s %s" % [pastel.green.bold("[COMMAND]"), pastel.bold(text)]
        end
        def put_bullet(text, level=1)
          indent = "  " * level
          puts "%s↳ #{pastel.blue.bold('[')} %s #{pastel.blue.bold(']')}" % [indent, pastel.dim(text)]
        end

        # Colorized Glyphs #
        def success_mark
          pastel.green.bold("✔")
        end
        def failure_mark
          pastel.red.bold("✘")
        end
        def prompt_mark
          pastel.magenta.bold("[PROMPT]")
        end

        # Misc #
        def newline
          puts "\n"
        end
        def die(msg)
          put_error msg
          exit
        end
      end
    end
  end
end
