require 'trello'
require 'yaml'
require 'uri'

if File.exist? File.expand_path("~/.trello2wr/config.yml")
  CONFIG = YAML.load_file(File.expand_path("~/.trello2wr/config.yml"))
else
  raise "ERROR: Config file not found!"
end

class Trello2WR
  include Trello
  include Trello::Authorization

  attr_reader :user, :board, :year, :week
  @@debug = true

  def initialize
    Trello::Authorization.const_set :AuthPolicy, OAuthPolicy

    # Read keys from ~/trello2wr/config.yml
    key = CONFIG['trello']['developer_public_key']
    secret = CONFIG['trello']['developer_secret']
    token = CONFIG['trello']['member_token']

    OAuthPolicy.consumer_credential = OAuthCredential.new key, secret
    OAuthPolicy.token = OAuthCredential.new token, nil

    self.log("*** Searching for user '#{CONFIG['trello']['username']}'")

    begin
      @user = Member.find(CONFIG['trello']['username'])
    rescue Trello::Error
      raise "ERROR: user '#{CONFIG['trello']['username']}' not found!}"
    end

    @year = Date.today.year
    @week = Date.today.cweek

    # FIXME: Allow more than one board
    # self.log("*** Getting lists for '#{CONFIG['trello']['boards'].first}' board")
    @board = @user.boards.find{|b| b.name == CONFIG['trello']['boards'].first}
  end

  def cards(board, list_name)
    self.log("*** Getting cards for '#{list_name}' list")

    if board
      if list_name == 'Done'
        list = board.lists.select{|l| l.name.include?('Done') && l.name.include?("##{(self.week-1).to_s}") }.last
      else
        list = board.lists.find{|l| l.name == list_name}
      end

      cards = list.cards.select{|c| c.member_ids.include? self.user.id}

      return cards
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
        body += "\nObjectives:\n" if list_name.downcase.include? 'to do'
      end

      self.cards(self.board, list_name).each do |card|
        if list_name.downcase.include? 'doing'
          body += "- #{card.name} (##{card.short_id}) [WIP]\n"
        else
          body += "- #{card.name} (##{card.short_id})\n"
        end
      end
    end

    body += "\n\nNOTE: (#<number>) are Trello board card IDs"
    self.escape(body)
  end

  def construct_mail_to_url(recipient, subject, body)
    if CONFIG['email'].has_key?('cc') && CONFIG['email']['cc'].present?
      URI::MailTo.build({:to => recipient, :headers => {"cc" => CONFIG['email']['cc'], "subject" => subject, "body" => body}}).to_s.inspect
    else
      URI::MailTo.build({:to => recipient, :headers => {"subject" => subject, "body" => body}}).to_s.inspect
    end
  end

  def escape(string)
    URI.escape(string, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
  end

  def export
    mailto = self.construct_mail_to_url(CONFIG['email']['recipient'], self.subject, self.body)
    self.log("*** Preparing email, please wait ...")

    system("#{CONFIG['email']['client']} #{mailto}")

    self.log("*** DONE")
  end

  def log(message)
    puts message if @@debug
  end
end
