$(document).on( "templateinit", (event) ->
  class WinkLightBulbItem extends pimatic.DimmerItem
  	
  	getTemplateName: -> "wink-lightbulb"

  	constructor: (templData, @device) ->
      super(templData, @device)

      @switchId = "switch-#{templData.deviceId}"
      stateAttribute = @getAttribute('state')
      unless stateAttribute?
        throw new Error("A switch device needs an state attribute!")
      @switchState = ko.observable(if stateAttribute.value() then 'on' else 'off')
      stateAttribute.value.subscribe( (newState) =>
        @_restoringState = true
        @switchState(if newState then 'on' else 'off')
        pimatic.try => @switchEle.flipswitch('refresh')
        @_restoringState = false
      )

    onSwitchChange: ->
      if @_restoringState then return
      stateToSet = (@switchState() is 'on')
      value = @getAttribute('state').value()
      if stateToSet is value
        return
      @switchEle.flipswitch('disable')
      deviceAction = (if @switchState() is 'on' then 'turnOn' else 'turnOff')

      doIt = (
        if @device.config.xConfirm then confirm __("""
          Do you really want to turn %s #{@switchState()}? 
        """, @device.name())
        else yes
      ) 

      restoreState = (if @switchState() is 'on' then 'off' else 'on')

      if doIt
        pimatic.loading "switch-on-#{@switchId}", "show", text: __("switching #{@switchState()}")
        @device.rest[deviceAction]({}, global: no)
          .done(ajaxShowToast)
          .fail( => 
            @_restoringState = true
            @switchState(restoreState)
            pimatic.try( => @switchEle.flipswitch('refresh'))
            @_restoringState = false
          ).always( => 
            pimatic.loading "switch-on-#{@switchId}", "hide"
            # element could be not existing anymore
            pimatic.try( => @switchEle.flipswitch('enable'))
          ).fail(ajaxAlertFail)
      else
        @_restoringState = true
        @switchState(restoreState)
        pimatic.try( => @switchEle.flipswitch('enable'))
        pimatic.try( => @switchEle.flipswitch('refresh'))
        @_restoringState = false

    afterRender: (elements) ->
      super(elements)
      @switchEle = $(elements).find('select')
      state = @getAttribute('state')
      if state.labels?
        capitaliseFirstLetter = (s) -> s.charAt(0).toUpperCase() + s.slice(1)
        @switchEle.find('option[value=on]').text(capitaliseFirstLetter state.labels[0])
        @switchEle.find('option[value=off]').text(capitaliseFirstLetter state.labels[1])

      @switchEle.flipswitch()
      $(elements).find('.ui-flipswitch').addClass('no-carousel-slide')

  pimatic.WinkLightBulbItem = WinkLightBulbItem
  pimatic.templateClasses['wink-lightbulb'] = WinkLightBulbItem
)

