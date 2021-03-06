require 'octokit'

class GithubHelper

  def self.create_issue(title)
    issues = call_github_api {|client, github_repo| client.issues(github_repo)}
    return if issues.nil?
    does_not_exist_issue = issues.select {|issue| issue[:title] == title}.empty?
    if does_not_exist_issue
      call_github_api {|client, github_repo| client.create_issue(github_repo, title)}
    end
  end

  def self.edit_issue(number, title)
    call_github_api {|client, github_repo| client.update_issue(github_repo, number, title)}
  end

  def self.labels_for_issue(number, options = {})
    call_github_api {|client, github_repo| client.labels_for_issue(github_repo, number, options)}
  end

  def self.add_labels_to_an_issue(number, labels)
    call_github_api {|client, github_repo| client.add_labels_to_an_issue(github_repo, number, labels)}
  end

  def self.close_issue(number)
    call_github_api {|client, github_repo| client.close_issue(github_repo, number)}
  end

  def self.list_issues(options = {})
    call_github_api do |client, github_repo|
      client.auto_paginate = true
      client.list_issues(github_repo, options)
    end
  end

  def self.add_label(label, color)
    call_github_api {|client, github_repo| client.add_label(github_repo, label, color)}
  end

  def self.update_label(label, options)
    call_github_api {|client, github_repo| client.update_label(github_repo, label, options)}
  end

  def self.call_github_api
    if Rails.application.secrets.github_token.blank? || Rails.application.secrets.github_repo.blank?
      p "GitHub API configuration is not enough"
      return
    end

    begin
      client = Octokit::Client.new(:access_token => Rails.application.secrets.github_token)
      yield(client, Rails.application.secrets.github_repo)
    rescue => e
      p e.message
    end
  end

end
