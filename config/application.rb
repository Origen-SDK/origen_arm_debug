class OrigenARMDebugApplication < Origen::Application

  # This information is used in headers and email templates, set it specific
  # to your application
  config.name     = "Origen ARM Debug"
  config.initials = "OrigenARMDebug"

  self.name = "origen_arm_debug"
  self.namespace = "OrigenARMDebug"
  config.rc_url = "git@github.com:Origen-SDK/origen_arm_debug.git"
  config.release_externally = true

  # To enable deployment of your documentation to a web server (via the 'origen web'
  # command) fill in these attributes.
  config.web_directory = "git@github.com:Origen-SDK/Origen-SDK.github.io.git/arm_debug"
  config.web_domain = "http://origen-sdk.org/arm_debug"
  
  config.semantically_version = true

  config.lint_test = { 
    # Require the lint tests to pass before allowing a release to proceed 
    run_on_tag: true, 
    # Auto correct violations where possible whenever 'origen lint' is run 
    auto_correct: true,  
    # Limit the testing for large legacy applications 
    #level: :easy, 
    # Run on these directories/files by default 
    #files: ["lib", "config/application.rb"], 
  } 
  
  # Ensure that all tests pass before allowing a release to continue 
  def validate_release 
    if !system("origen examples") || !system("origen specs") 
      puts "Sorry but you can't release with failing tests, please fix them and try again." 
      exit 1 
    else 
      puts "All tests passing, proceeding with release process!" 
    end 
  end 
  
  # Run code coverage when deploying the web site 
  def before_deploy_site 
    Dir.chdir Origen.root do 
      system "origen examples -c" 
      system "origen specs -c" 
      dir = "#{Origen.root}/web/output/coverage"        
      FileUtils.remove_dir(dir, true) if File.exists?(dir)  
      system "mv #{Origen.root}/coverage #{dir}" 
    end 
  end 
 
  # Deploy the website automatically after a production tag 
  def after_release_email(tag, note, type, selector, options) 
    command = "origen web compile --remote --api" 
    Dir.chdir Origen.root do 
      system command 
    end 
  end 

end
