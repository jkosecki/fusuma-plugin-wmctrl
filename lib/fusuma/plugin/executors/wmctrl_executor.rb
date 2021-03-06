# frozen_string_literal: true

require 'posix/spawn'

module Fusuma
  module Plugin
    module Executors
      # Control Window or Workspaces by executing wctrl
      class WmctrlExecutor < Executor
        # execute wmctrl command
        # @param event [Event]
        # @return [nil]
        def execute(event)
          return if search_command(event).nil?

          MultiLogger.info(wmctrl: search_command(event))
          pid = POSIX::Spawn.spawn(search_command(event))
          Process.detach(pid)
        end

        # check executable
        # @param event [Event]
        # @return [TrueClass, FalseClass]
        def executable?(event)
          event.tag.end_with?('_detector') &&
            event.record.type == :index &&
            search_command(event)
        end

        # @param event [Event]
        # @return [String]
        # @return [NilClass]
        def search_command(event)
          search_workspace_command(event) || search_window_command(event)
        end

        private

        # @param event [Event]
        # @return [String]
        # @return [NilClass]
        def search_workspace_command(event)
          index = Config::Index.new([*event.record.index.keys, :workspace])

          direction = Config.search(index)
          return unless direction.is_a?(String)

          Workspace.move_command(direction: direction)
        end

        # @param event [Event]
        # @return [String]
        # @return [NilClass]
        def search_window_command(event)
          index = Config::Index.new([*event.record.index.keys, :window])

          case property = Config.search(index)
          when 'prev', 'next'
            Window.move_command(direction: property)
          when 'fullscreen'
            Window.fullscreen(method: 'toggle')
          when 'maximized'
            Window.maximized(method: 'toggle')
          when 'close'
            Window.close
          when Hash
            if property[:fullscreen]
              Window.fullscreen(method: property[:fullscreen])
            elsif property[:maximized]
              Window.maximized(method: property[:maximized])
            end
          end
        end

        # Manage workspace
        class Workspace
          class << self
            # get workspace number
            # @return [Integer]
            def current_workspace_num
              text = `wmctrl -d`.split("\n").grep(/\*/).first
              text.chars.first.to_i
            end

            def move_command(direction:)
              workspace_num = case direction
                              when 'next'
                                current_workspace_num + 1
                              when 'prev'
                                current_workspace_num - 1
                              else
                                raise "#{direction} is invalid key"
                              end
              "wmctrl -s #{workspace_num}"
            end
          end
        end

        # Manage Window
        class Window
          class << self
            # @param method [String] "toggle" or "add" or "remove"
            def maximized(method:)
              "wmctrl -r :ACTIVE: -b #{method},maximized_vert,maximized_horz"
            end

            def close
              'wmctrl -c :ACTIVE:'
            end

            # @param method [String] "toggle" or "add" or "remove"
            def fullscreen(method:)
              "wmctrl -r :ACTIVE: -b #{method},fullscreen"
            end

            def move_command(direction:)
              workspace_num = case direction
                              when 'next'
                                Workspace.current_workspace_num + 1
                              when 'prev'
                                Workspace.current_workspace_num - 1
                              else
                                raise "#{direction} is invalid key"
                              end
              "wmctrl -r :ACTIVE: -t #{workspace_num} ; wmctrl -s #{workspace_num}"
            end
          end
        end
      end
    end
  end
end
