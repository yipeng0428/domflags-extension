#### CONTENT SCRIPT

## toggleDomflag for keyboard shortcuts
## create new tabs to test
@toggleDomflag = (el) ->
  if el.hasAttribute('domflag')
    el.removeAttribute('domflag', '')
  else
    el.setAttribute('domflag', '')

$(document).ready ->
  class WatchDOMFlags
    constructor: (domflags) ->
      @domflags = domflags
      @domflagsPanel = undefined
      @panelList = undefined
      @shadowRoot = undefined
      @flagStrings = []

      @backgroundListener()
      @setupDomObserver()

    backgroundListener: ->
      ## Receive requests from background script
      chrome.runtime.onMessage.addListener (message, sender, sendResponse) =>
        if message is "remove"
          @domflagsPanel.remove()
          @domflagsPanel = @shadowRoot.getElementById('domflags-panel')

        if message is "create" and @domflags.length > 0
          unless @domflagsPanel ## prevent duplicates
            @addNodesToPanel(@domflags)


    appendDomflagsPanel: ->
      cssPath = chrome.extension.getURL("src/inject/inject.css")
      styleTag = """<style type="text/css" media="screen">@import url(#{cssPath});</style>"""
      panelHTML =  """
              <domflags-panel id="domflags-panel" class="bottom left opened">
                <domflags-header class="domflags-header">DOMFLAGS</domflags-header>
                <domflags-button class="domflags-button right"></domflags-button>
                <domflags-ol class="domflags-ol"></domflags-ol>
              </domflags-panel>
              """
      unless document.getElementById('domflags-root')?
        $(document.body).append '<domflags id="domflags-root"></domflags>' # native JS bug
        @shadowRoot = document.querySelector('#domflags-root').createShadowRoot()
        @shadowRoot.innerHTML = styleTag

      @shadowRoot.innerHTML += panelHTML
      @domflagsPanel = @shadowRoot.getElementById('domflags-panel')
      @panelList = @domflagsPanel.querySelector('.domflags-ol')
      @createPanelListeners()


    createPanelListeners: ->
      @domflagsPanel.addEventListener 'click', (event) =>
        if event.target.className is 'domflags-li'
          key = $(event.target).attr('data-key')
          chrome.runtime.sendMessage
            name: "panelClick"
            key: key

        else if event.target.className is 'domflags-header'
          if @domflagsPanel.classList.contains('opened')
            listHeight = $(@panelList).outerHeight() + 1;
            @domflagsPanel.classList.remove('opened')
            @domflagsPanel.classList.add('closed')

          else if @domflagsPanel.classList.contains('closed')
            listHeight = 0
            @domflagsPanel.classList.remove('closed')
            @domflagsPanel.classList.add('opened')

          $(@domflagsPanel).css('transform', "translateY(#{listHeight}px)")

        else if event.target.classList[0] is 'domflags-button'
          targetPos = event.target.classList[1]

          if      targetPos is "left"  then oldPos = "right"
          else if targetPos is "right" then oldPos = "left"

          @domflagsPanel.classList.remove(oldPos)
          @domflagsPanel.classList.add(targetPos)
          event.target.classList.remove(targetPos)
          event.target.classList.add(oldPos)

    nodeListToArray: (nodeList) ->
      Array::slice.call(nodeList)

    elToString: (node) ->
      tagName   = node.tagName.toLowerCase()
      idName    = if node.id then "#" + node.id else ""
      className = if node.className then "." + node.className else ""
      return tagName + idName + className

    cacheDomflags: ->
      @domflags = document.querySelectorAll('[domflag]')

    calibrateIndexes: ->
      tags = @panelList.getElementsByTagName('domflags-li')
      tag.setAttribute 'data-key', i for tag, i in tags

    addNodesToPanel: (newNodes) ->
      newNodes = @nodeListToArray(newNodes)
      unless @domflagsPanel?
        @appendDomflagsPanel()

      panelItems = @domflagsPanel.getElementsByClassName('domflags-li')
      for node in newNodes
        elString = @elToString(node)

        if node.hasAttribute('domflag')
          @cacheDomflags()
          index = $(@domflags).index(node)
          @flagStrings.splice(index, 0, elString)
          el = "<domflags-li class='domflags-li' data-key='#{index}'>#{elString}</domflags-li>"

          if panelItems.length > 0
            if index >= 1
              $(panelItems[index - 1]).after(el)
            else
              $(panelItems[0]).before(el)
          else
            @panelList.innerHTML += el
      @calibrateIndexes()

    removeNodesFromPanel: (deletedNodes) ->
      panelItems = @domflagsPanel.getElementsByClassName('domflags-li')
      for node in deletedNodes.slice(0).reverse()
        index = $(@domflags).index(node)
        @flagStrings.splice(index, 1)
        $(panelItems[index]).remove()
      @cacheDomflags()
      @calibrateIndexes()

    # // DOM OBSERVER
    # /////////////////////////////////
    setupDomObserver: ->
      observer = new MutationObserver((mutations) =>
        newNodes = []
        deletedNodes = []

        for mutation in mutations
          ## A node has been added / deleted
          if mutation.type is "childList"
            addedNodes =
              mutation: mutation.addedNodes
              panelArray: newNodes
            removedNodes =
              mutation: mutation.removedNodes
              panelArray: deletedNodes

            nodeChange = switch
              when addedNodes.mutation.length   > 0 then addedNodes
              when removedNodes.mutation.length > 0 then removedNodes
              else undefined

            continue if not nodeChange?

            # console.log nodeChange, nodeChange.mutation
            for node in nodeChange.mutation
              continue if node.nodeName is "#text"

              if (node.hasAttribute('domflag')) and (node not in nodeChange.panelArray)
                nodeChange.panelArray.push(node)

              for child in node.querySelectorAll('[domflag]')
                nodeChange.panelArray.push(child) if child not in nodeChange.panelArray
                continue
              continue

          ## Attribute has been added / deleted
          else if mutation.type is "attributes"
            if mutation.target.hasAttribute('domflag')
              newNodes.push(mutation.target)
            else
              deletedNodes.push(mutation.target)
          continue

        # console.log "Deleted", deletedNodes, "Added", newNodes
        @removeNodesFromPanel(deletedNodes) if deletedNodes.length > 0
        @addNodesToPanel(newNodes) if newNodes.length > 0
      )

      config =
        attributes: true
        attributeFilter: ['domflag']
        attributeOldValue: false
        childList: true
        subtree: true

      observer.observe document.body, config

  ## Instantiate WatchDOMFlags
  domflags = document.querySelectorAll('[domflag]')
  new WatchDOMFlags(domflags)
