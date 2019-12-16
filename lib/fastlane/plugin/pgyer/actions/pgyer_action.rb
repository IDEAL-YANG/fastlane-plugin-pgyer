require 'faraday'
require 'faraday_middleware'

module Fastlane
  module Actions
    class PgyerAction < Action
      def self.run(params)
        UI.message("The pgyer plugin is working.")

        api_host = "https://www.pgyer.com/apiv2/app/upload"
        api_key = params[:api_key]
        channel_shortcut = params[:channel_shortcut]

        build_file = [
          params[:ipa],
          params[:apk]
        ].detect { |e| !e.to_s.empty? }

        if build_file.nil?
          UI.user_error!("You have to provide a build file")
        end

        UI.message "build_file: #{build_file}"

        password = params[:password]
        if password.nil?
          UI.user_error!("You have to provide a password")
        end

        update_description = params[:update_description]
        if update_description.nil?
          update_description = ""
        end

        install_type = params[:install_type]
        if install_type.nil?
          install_type = "2"
        end

        # start upload
        conn_options = {
          request: {
            timeout:       1000,
            open_timeout:  300
          }
        }

        pgyer_client = Faraday.new(nil, conn_options) do |c|
          c.request :multipart
          c.request :url_encoded
          c.response :json, content_type: /\bjson$/
          c.adapter :net_http
        end

        params = {
            '_api_key' => api_key,
            'buildChannelShortcut' => channel_shortcut,
            'buildPassword' => password,
            'buildUpdateDescription' => update_description,
            'buildInstallType' => install_type,
            'file' => Faraday::UploadIO.new(build_file, 'application/octet-stream')
        }

        UI.message "Start upload #{build_file} to pgyer..."

        response = pgyer_client.post api_host, params
        info = response.body

        if info['code'] != 0
          UI.user_error!("PGYER Plugin Error: #{info['message']}")
        end

        UI.success " Upload success. Visit this URL to see: https://www.pgyer.com/#{info['data']['buildShortcutUrl']} "
      end

      def self.description
        "distribute app to pgyer beta testing service"
      end

      def self.authors
        ["rexshi"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.details
        # Optional:
        "distribute app to pgyer beta testing service"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :api_key,
                                  env_name: "PGYER_API_KEY",
                               description: "api_key in your pgyer account",
                                  optional: false,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :channel_shortcut,
                                  env_name: "PGYER_CHANNEL_SHORTCUT",
                               description: "(选填)所需更新的指定渠道的下载短链接，只可指定一个渠道，字符串型，如：abcd",
                                  optional: true,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :apk,
                                       env_name: "PGYER_APK",
                                       description: "Path to your APK file",
                                       default_value: Actions.lane_context[SharedValues::GRADLE_APK_OUTPUT_PATH],
                                       optional: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("Couldn't find apk file at path '#{value}'") unless File.exist?(value)
                                       end,
                                       conflicting_options: [:ipa],
                                       conflict_block: proc do |value|
                                         UI.user_error!("You can't use 'apk' and '#{value.key}' options in one run")
                                       end),
          FastlaneCore::ConfigItem.new(key: :ipa,
                                       env_name: "PGYER_IPA",
                                       description: "Path to your IPA file. Optional if you use the _gym_ or _xcodebuild_ action. For Mac zip the .app. For Android provide path to .apk file",
                                       default_value: Actions.lane_context[SharedValues::IPA_OUTPUT_PATH],
                                       optional: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("Couldn't find ipa file at path '#{value}'") unless File.exist?(value)
                                       end,
                                       conflicting_options: [:apk],
                                       conflict_block: proc do |value|
                                         UI.user_error!("You can't use 'ipa' and '#{value.key}' options in one run")
                                       end),
          FastlaneCore::ConfigItem.new(key: :password,
                                  env_name: "PGYER_PASSWORD",
                               description: "(必填) 设置App安装密码",
                                  optional: false,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :update_description,
                                  env_name: "PGYER_UPDATE_DESCRIPTION",
                               description: "(选填) 版本更新描述，请传空字符串，或不传。",
                                  optional: true,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :install_type,
                                  env_name: "PGYER_INSTALL_TYPE",
                               description: "(必填)应用安装方式，值为(2,3)。2：密码安装，3：邀请安装. Please set as a int",
                                  optional: false,
                                      type: Integer)
        ]
      end

      def self.is_supported?(platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://github.com/fastlane/fastlane/blob/master/fastlane/docs/Platforms.md
        #
        [:ios, :mac, :android].include?(platform)
        true
      end
    end
  end
end
