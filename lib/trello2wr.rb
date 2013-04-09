require 'trello'
require 'yaml'
require 'uri'

if File.exist? File.expand_path("~/.trello2wr/config.yml")
  CONFIG = YAML.load_file(File.expand_path("~/.trello2wr/config.yml"))
else
  raise "ERROR: Config file not found!"
end

class Trello2WR
  attr_reader :user, :year, :week

  @@debug = false

  def initialize
    @year = Date.today.year
    @week = Date.today.cweek
    @user = sign_in
  end

  # Get Trello cards
  # TODO: find by trello username or email
  def sign_in
    self.log("*** Trello API basic authorization")

    Trello.configure do |config|
      config.developer_public_key = CONFIG['trello']['developer_public_key']
      config.member_token = CONFIG['trello']['member_token']
    end

    self.log("*** Find user: #{CONFIG['trello']['username']}")

    begin
      return Trello::Member.find(CONFIG['trello']['username'])
    rescue Trello::Error
      raise "ERROR: user '#{CONFIG['default']['username']}' not found!}"
    end
  end

  def cards(name)
    name = "Done (#{self.year}##{self.week-1})" if name == "Done"

    self.log("*** Get '#{name}' cards")

    #FIXME: allow more than one board
    board = self.user.boards.first.lists.find{|l| l.name == name}

    if board
      cards = board.cards.select{|c| c.member_ids.include? self.user.id}
      return cards.map{|c| "- #{c.name.downcase} (##{c.short_id}) #{'[WIP]' if name == 'Doing' }\n"}
    else
      raise "ERROR: Board '#{name}' not found!"
    end
  end

  # Prepare A&O mail
  def subject
    self.escape("A&O Week ##{self.week} #{self.user.username}")
  end

  def body
    body = "Accomplishments:\n"
    self.cards("Done").each{|line| body += line}

    body += "\nObjectives:\n"
    self.cards("Doing").each{|line| body += line}
    self.cards("To Do").each{|line| body += line}

    body += "\n\nNOTE: (#<number>) are Trello board card IDs"
    self.escape(body)
  end

  def construct_mail_to_url(recipient, subject, body)
    if CONFIG['email']['cc'].empty?
      URI::MailTo.build({:to => recipient, :headers => {"subject" => subject, "body" => body}}).to_s.inspect
    else
      URI::MailTo.build({:to => recipient, :headers => {"cc" => CONFIG['email']['cc'], "subject" => subject, "body" => body}}).to_s.inspect
    end
  end

  def escape(string)
    URI.escape(string, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
  end

  def export
    mailto = self.construct_mail_to_url(CONFIG['email']['recipient'], self.subject, self.body)

    self.log("*** Format email and open email client")

    # FIXME: add support for another email clients
    system("#{CONFIG['email']['client']} #{mailto}")
  end

  def log(message)
    puts message if @@debug
  end
end
