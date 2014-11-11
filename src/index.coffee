_ = require 'underscore'
mandrill = require 'mandrill-api/mandrill'
Hoek = require 'hoek'
i18n = require './i18n'

###
Registers the plugin.  
###
module.exports.register = (plugin, options = {}, cb) ->
  Hoek.assert options.senderName, i18n.optionsSenderNameRequired
  Hoek.assert options.senderEmail, i18n.optionsSenderEmailRequired

  defaults = 
    templateNameMap : {}
    verbose : false

  options = Hoek.applyToDefaults defaults, options

  mandrillClient = null
  templateNameMapping = options.templateNameMap

  ###
  This is lenient to simplify testing.
  ###
  if options.key
    mandrillClient = new mandrill.Mandrill options.key
    console.log "Mandrill active with #{options.key}" if options.verbose
  else
    console.log "Mandrill disabled - no key" if options.verbose
    plugin.log ['configuration','warning'], i18n.emailSendDisabled 

  send = (receiverName,receiverEmail,payload = {},subject,templateName,cb2 = ->) ->
    console.log "Sending to: #{receiverName} / #{receiverEmail} / #{templateName}" if options.verbose
    console.log "Payload: #{JSON.stringify(payload)}" if options.verbose
    console.log "Subject: #{subject}" if options.verbose

    templateContent = []
    for k in _.keys payload
      templateContent.push 
        name : k
        content: payload[k]

    templateName = templateNameMapping[templateName] || templateName # If it is mapped, take the mapped one, otherwise pass it 1:1

    console.log "Mapped templateName: #{templateName}" if options.verbose

    sendTemplateOptions = 
      template_name: templateName
      template_content: templateContent
      async: true
      message: 
        subject: subject
        from_email: options.senderEmail
        from_name: options.senderName
        to: [
            email: receiverEmail
            name: receiverName
          ] 
        track_opens: true
        auto_text: true
        auto_html: true
        inline_css: true

    success = (result) ->
      console.log "Mandrill success: #{JSON.stringify(result)}" if options.verbose

      plugin.log ['mandrill','email-sent'],i18n.emailQueuedSuccess, result
      cb2 null,result

    error = (err) ->
      console.log "Mandrill error: #{JSON.stringify(err)}" if options.verbose

      plugin.log ['mandrill','email-not-sent','error'],i18n.emailNotQueuedFailure, err
      cb2 err

    if mandrillClient
      console.log "Sending to Mandrill: #{JSON.stringify(sendTemplateOptions)}" if options.verbose
      mandrillClient.messages.sendTemplate sendTemplateOptions, success,error
    else
      console.log "Faking mandrill send" if options.verbose
      success {} # Mock mode, need to think about result

  plugin.expose 'mandrillClient', mandrillClient
  plugin.expose 'send', send
  plugin.expose 'templateNameMapping', templateNameMapping

  cb()

module.exports.register.attributes =
  pkg: require '../package.json'

