require 'trello'
require 'yaml'
require 'uri'

if File.exist? File.expand_path("~/.trello2wr/config.yml")
  CONFIG = YAML.load_file(File.expand_path("~/.trello2wr/config.yml"))
else
  raise "ERROR: Config file not found!"
end

class Trello2WR
  attr_reader :user, :board, :year, :week

  STATES = {"complete" => "DONE", "incomplete" => "WIP"}
  LISTS = ["Done", "Doing", "To Do"]

  @@debug = true

  def initialize
    @year = Date.today.year
    @week = Date.today.cweek
    @user = sign_in

    #FIXME: allow more than one board
    @board = self.user.boards.find{|b| b.name == "Happy Customer"}
  end

  # Get Trello cards
  # TODO: find by trello username or email
  def sign_in
    self.log("*** Connecting to Trello Public API")

    Trello.configure do |config|
      config.developer_public_key = CONFIG['trello']['developer_public_key']
      config.member_token = CONFIG['trello']['member_token']
    end

    self.log("*** Searching for user '#{CONFIG['trello']['username']}'")

    begin
      return Trello::Member.find(CONFIG['trello']['username'])
    rescue Trello::Error
      raise "ERROR: user '#{CONFIG['default']['username']}' not found!}"
    end
  end

  def cards(board, list_name)
    list_name = "Done (#{self.year}##{self.week-1})" if list_name == "Done"
    self.log("*** Getting cards for '#{list_name}' list")

    if board
      list = board.lists.find{|l| l.name == list_name}
      cards = list.cards.select{|c| c.member_ids.include? self.user.id}
      return cards
    else
      raise "ERROR: Board '#{name}' not found!"
    end
  end

  def checklists(card)
    string = ''

    card.checklists.map do |checklist|
      string += "\n    #{checklist.name}:\n"
      string += checklist.check_items.each_with_index.map{|item, i| "    [#{i+1}] #{item['name']} [#{STATES[item['state']]}]"}.join("\n")
    end

    string
  end

  # Prepare A&O mail
  def subject
    self.escape("A&O Week ##{self.week} #{self.user.username}")
  end

  def body
    body = "Accomplishments:\n"

    LISTS.each do |list_name|
      self.cards(self.board, list_name).each do |card|
        body += "- #{card.name} (##{card.short_id}) #{'[WIP]' if list_name == 'Doing' }\n"
      end

      body += "\nObjectives:\n" if list_name == "Done"
    end

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
    self.log("*** Preparing email, please wait ...")

    system("#{CONFIG['email']['client']} #{mailto}")

    self.log("*** DONE")
  end

  def log(message)
    puts message if @@debug
  end
end
