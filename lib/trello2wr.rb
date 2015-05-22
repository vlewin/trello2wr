require 'trello'
require 'yaml'
require 'uri'

class Trello2WR
  include Trello
  include Trello::Authorization

  attr_reader :user, :board, :week
  @@debug = true

  def initialize(sprint=nil, week)
    @config = load_config

    authenticate

    @sprint = sprint
    @week = week

    @username = @config['trello']['username']
    @user = find_member(@username)
    @board = find_board
  end

  def authenticate
    Trello::Authorization.const_set :AuthPolicy, OAuthPolicy
    OAuthPolicy.consumer_credential = OAuthCredential.new @config['trello']['developer_public_key'], @config['trello']['developer_secret']
    OAuthPolicy.token = OAuthCredential.new @config['trello']['member_token'], nil
  end

  def load_config
    # Read keys from ~/trello2wr/config.yml
    if File.exist? File.expand_path("~/.trello2wr/config.yml")
      YAML.load_file(File.expand_path("~/.trello2wr/config.yml"))
    else
      raise "ERROR: Config file not found!"
    end
  end

  def find_member(username)
    self.log("*** Searching for user '#{username}'")

    begin
      Member.find(username)
    rescue Trello::Error
      raise "ERROR: user '#{username}' not found!}"
    end
  end

  def find_board
    board = @config['trello']['boards'].first
    self.log("*** Getting lists for '#{board}' board")
    @user.boards.find{|b| b.name == board}
  end

  def cards(board, list_name)
    self.log("*** Getting cards for '#{list_name}' list")

    if board
      lists = board.lists

      if list_name == 'Done'
        lists = lists.select{|l| l.name.include?('Done')}
        list = @sprint ? lists.select{|l| l.name.include?(@sprint.to_s) }.first : lists.sort_by{|l| l.id }.last

        self.log("*** Getting cards for '#{list.name}' list (week #{@week})")
        list.cards.select{|c| c.last_activity_date.to_datetime.cweek == @week && c.member_ids.include?(user.id) }
      else
        lists.find{|l| l.name == list_name}.cards.select{|c| c.member_ids.include? self.user.id}
      end
    else
      raise "ERROR: Board '#{list_name}' not found!"
    end
  end

  # Prepare mail header
  def subject
    self.escape("A&O Week ##{self.week} #{self.user.username}")
  end

  # Prepare mail body
  def body
    body = ''
    ['Done', 'In review', 'To Do', 'Doing'].each do |list_name|
      if list_name.downcase.include? 'done'
        body += "Accomplishments:\n"
      elsif list_name.downcase.include? 'review'
        body += "\nIn review:\n"
      elsif list_name.downcase.include? 'to do'
        body += "\nObjectives:\n"
      end

      self.cards(board, list_name).each do |card|
        if list_name.downcase.include? 'doing'
          body += "- #{card.name} (##{card.short_id}) [WIP]\n"
        else
          body += "- #{card.name} (##{card.short_id})\n"
        end
      end
    end

    body += "\n\nNOTE: (#<number>) are Trello board card IDs"

    escape(body)
  end

  def construct_mail_to_url(recipient, subject, body)
    headers = { subject: subject, body: body }
    headers[:cc] = @config['email']['cc'] if @config['email'].has_key?('cc') && @config['email']['cc'].present?

    URI::MailTo.build({:to => recipient, :headers => headers.stringify_keys}).to_s.inspect
  end

  def escape(string)
    URI.escape(string, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
  end

  def export
    mailto = self.construct_mail_to_url(@config['email']['recipient'], subject, body)
    self.log("*** Preparing email, please wait ...")

    system("#{@config['email']['client']} #{mailto}")

    self.log("*** DONE")
  end

  def log(message)
    puts message if @@debug
  end
end
