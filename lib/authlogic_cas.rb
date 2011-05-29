require "authlogic_cas/session"

Authlogic::Session::Base.send(:include, AuthlogicCas::Session)
ActionController::Base.send(:append_before_filter, CASClient::Frameworks::Rails::Filter)
