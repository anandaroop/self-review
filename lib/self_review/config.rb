require "yaml"
require "fileutils"

module SelfReview
  class Config
    CONFIG_DIR = File.expand_path("~/.config/self-review")
    CONFIG_FILE = File.join(CONFIG_DIR, "config.yml")

    def self.config_dir
      CONFIG_DIR
    end

    def self.config_file
      CONFIG_FILE
    end

    def self.load
      return {} unless File.exist?(CONFIG_FILE)

      YAML.load_file(CONFIG_FILE) || {}
    rescue Psych::SyntaxError
      {}
    end

    def self.save(config)
      FileUtils.mkdir_p(CONFIG_DIR)
      File.write(CONFIG_FILE, YAML.dump(config))
      File.chmod(0o600, CONFIG_FILE)
    end

    def self.github_token
      load["github_token"]
    end

    def self.jira_url
      load["jira_url"]
    end

    def self.jira_username
      load["jira_username"]
    end

    def self.jira_token
      load["jira_token"]
    end
  end
end
