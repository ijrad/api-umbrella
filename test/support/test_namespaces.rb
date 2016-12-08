# Define namespace modules for all the test classes.
#
# We pre-define all these here so that we can use the shorter, more succinct
# single-line/non-nested syntax in all the test files.
module Test
  module AdminUi; end

  module Apis
    module Admin
      module Stats; end
    end

    module V1
      module AdminGroups; end
      module AdminPermissions; end
      module Admins; end
      module Analytics; end
      module ApiScopes; end
      module Apis; end
      module Config; end
      module Users; end
      module WebsiteBackends; end
    end
  end

  module Processes; end

  module Proxy
    module ApiKeyValidation; end
    module ApiMatching; end
    module Caching; end
    module Dns; end
    module FormattedErrors; end
    module Gzip; end
    module KeepAlive; end
    module Logging; end
    module RateLimits; end
    module RequestRewriting; end
    module ResponseRewriting; end
    module Routing; end
  end

  module TestingSanityChecks; end
end
