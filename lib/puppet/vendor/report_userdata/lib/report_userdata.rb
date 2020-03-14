# (c) 2020 Open Infrastructure Services, LLC
#
# This file modifies the behavior of Puppet.  The implementation takes great
# care not to affect the load order of puppet ruby code because changing the
# load order is known to be fragile and cause undefined name error exceptions.
# This remains true in Puppet 5 and 6.
#
# Module.method_added(method_name) is used to maximize robustness.  Methods
# which already exist are patched immediately when this code lodes, otherwise,
# the methods are patched immediately after they're defined.  This code loads
# very early from Puppet::Vendor, so the time a method exists but is unpatched
# as we want is minimized.
#
# Minimizing the time two different method implementations exist increases
# robustness by eliminating the chance of race conditions.  Using this
# technique methods are patched before the file they're defined in is finished
# being loaded.

module PuppetX
  module ReportExtensions
    # User specified data stored as a Hash.  The value must be serializable to
    # JSON.  The intent of this userdata is to allow end users to embed their
    # own Patch the initialize method if not already patched.
    def self.patch_initialize(klass)
      klass.class_eval do
        alias_method :__original_initialize, :initialize

        def initialize(*args)
          @userdata = {}
          send(:__original_initialize, *args)
        end
      end
    end

    def self.patch_to_data_hash(klass)
      klass.class_eval do
        alias_method :__original_to_data_hash, :to_data_hash
        def to_data_hash
          hash = __original_to_data_hash
          hash['userdata'] = @userdata unless @userdata.nil?
          hash
        end
      end
    end

    def self.patch_initialize_from_hash(klass)
      klass.class_eval do
        alias_method :__original_initialize_from_hash, :initialize_from_hash
        def initialize_from_hash(data)
          @userdata = data.fetch('userdata', {})
          __original_initialize_from_hash(data)
        end
      end
    end
  end

  # Extend Puppet::Configurer to populate Report#userdata with classes and
  # roles.  The intent is to faciliate queries over a large dataset of reports
  # selecting by role and class.
  module ConfigurerExtensions
    def self.patch_apply_catalog(klass)
      klass.class_eval do
        alias_method :__original_apply_catalog, :apply_catalog
        # Extend the behavior of apply_catalog to store the classes enforced on
        # the agent in the report so that big queries may select report data
        # grouped by classes.
        def apply_catalog(*args)
          # The first thing we do is execute Puppet's normal behavior to ensure
          # normal catalog application works.
          report = __original_apply_catalog(*args)
          catalog = args.first
          # If the arity of apply_catalog changes, or the catalog API changes,
          # don't continue.
          if catalog.respond_to?(:classes)
            classes = catalog.classes.sort
            report.userdata[:roles] = classes.select do |s|
              s.start_with? "role::"
            end
            report.userdata[:profiles] = classes.select do |s|
              s.start_with? "profile::"
            end
            report.userdata[:classes] = classes
          else
            Puppet.warning("Puppet's catalog API has changed, could not extract classes from the catalog.  Contact Open Infrastructure Services to update #{__FILE__} to collect roles from the catalog for reporting.  See https://github.com/openinfrastructure/puppet-report_userdata")
          end
          report
        end
      end
    end
  end
end

module Puppet; end
class Puppet::Transaction; end

class Puppet::Transaction::Report
  # Record methods which have been patched.
  @patched_methods = {}

  # The module method named patch_foo will be called when method foo is defined
  # to patch a method foo, simply define ReportExteions.patch
  def self.method_added(m)
    return if @patched_methods.fetch(m, false)
    patch_method = "patch_#{m}".to_sym
    if PuppetX::ReportExtensions.respond_to?(patch_method)
      # Prevent StackOverflow when the patched method is added
      @patched_methods[m] = true
      PuppetX::ReportExtensions.send(patch_method, self)
    end
  end

  # If the class has already been loaded by Puppet when this file is loaded
  # method_added won't be automatically called.  We call method_added here to
  # patch already defined methods.
  self.instance_methods.each { |m| method_added(m) }
  # Special case for initialize, which isn't technically an instance method
  method_added(:initialize) if self.instance_method(:initialize).owner == self

  # User data intended for use by end users to convey their own values from an
  # agent to a report processor on the server.
  # @return [Hash] userdata
  attr_accessor :userdata
end

class Puppet::Configurer
  # Record methods which have been patched.
  @patched_methods = {}

  # The module method named patch_foo will be called when method foo is defined
  # to patch a method foo, simply define ReportExteions.patch
  def self.method_added(m)
    return if @patched_methods.fetch(m, false)
    patch_method = "patch_#{m}".to_sym
    if PuppetX::ConfigurerExtensions.respond_to?(patch_method)
      # Prevent StackOverflow when the patched method is added
      @patched_methods[m] = true
      PuppetX::ConfigurerExtensions.send(patch_method, self)
    end
  end

  # If the class has already been loaded by Puppet when this file is loaded
  # method_added won't be automatically called.  We call method_added here to
  # patch already defined methods.
  self.instance_methods.each { |m| method_added(m) }
  # Special case for initialize, which isn't technically an instance method
  method_added(:initialize) if self.instance_method(:initialize).owner == self
end
