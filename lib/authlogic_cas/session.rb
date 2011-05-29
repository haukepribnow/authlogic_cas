module AuthlogicCas
  module Session
    def self.included(klass)
      klass.class_eval do
        include Methods
      end
    end

    module ActionControllerReplaceRedirectMethod
      # When including this module into the ActionController::Base class, the
      # redirect_to_full_url method will be intercepted by a method that logs
      # us out of the CAS.
      def self.included(klass)
        klass.class_eval do

          # Make sure that this method has a very silly name that no one else would use!
          # (Dirty, I know... if you know a better way, feel free to put it in here.)
          def redirect_to_full_url_newnewnewnew(url, status)
            # Replace this very method with the original one again
            ActionController::Base.class_eval("alias :redirect_to_full_url :redirect_to_full_url_before")

            # Call the log out function with the given url
            # (this call will call redirect_to_full_url; that's why we had to
            # "restore" the original method again)
            CASClient::Frameworks::Rails::Filter.logout(self, url)
          end
          
          alias :redirect_to_full_url_before :redirect_to_full_url
          alias :redirect_to_full_url :redirect_to_full_url_newnewnewnew
        end
      end
    end

    module Methods
      def self.included(klass)
        klass.class_eval do
          skips = [:persist_by_params,:persist_by_session,:persist_by_http_auth]
          if respond_to? :skip_callback
            skips.each {|cb| skip_callback :persist, cb }
          else
            persist.reject {|cb| skips.include?(cb.method)}
          end
          persist :persist_by_cas, :if => :authenticating_with_cas?

          # Replace the destroy method to be able to put the redirect interceptor into place.
          alias :destroy_before :destroy
          alias :destroy :destroy_new
        end
      end

      # Replace the destroy method to put the redirect interceptor into place.
      def destroy_new
        ActionController::Base.send(:include,ActionControllerReplaceRedirectMethod)
        destroy_before
      end

      # no credentials are passed in: the CAS server takes care of that and saving the session
      # def credentials=(value)
      #   values = [:garbage]
      #   super
      # end

      def persist_by_cas
        session_key = CASClient::Frameworks::Rails::Filter.client.username_session_key

        unless controller.session[session_key].blank?
          self.attempted_record = search_for_record("find_by_#{klass.login_field}", controller.session[session_key])
        end

        !self.attempted_record.nil?
      end

      def authenticating_with_cas?
        attempted_record.nil? && errors.empty? && cas_defined?
      end

      private

      def cas_defined?
        defined?(CASClient::Frameworks::Rails::Filter) && !CASClient::Frameworks::Rails::Filter.config.nil?
      end
    end
  end
end
