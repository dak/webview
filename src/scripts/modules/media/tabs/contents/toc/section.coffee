define (require) ->
  _ = require('underscore')
  TocDraggableView = require('cs!./draggable')
  TocPageView = require('cs!./page')
  SectionNameModal = require('cs!./modals/section-name/section-name')
  linksHelper = require('cs!helpers/links.coffee')
  router = require('cs!router')
  template = require('hbs!./section-template')
  require('less!./section')

  return class TocSectionView extends TocDraggableView
    template: template
    templateHelpers:
      editable: -> @editable
      visible: ->
        @model.get('visible')
    itemViewContainer: '> ul'

    events:
      'click > div > .section-wrapper': 'toggleSection'
      'click > div > .section-wrapper > .title': 'toggleOrLoad'
      'keydown > div > .section-wrapper': 'toggleSectionWithKeyboard'
      'click > div > .remove': 'removeNode'
      'click > div > .edit': 'editNode'

    initialize: () ->
      @content = @model.get('book') or @model
      @editable = @content.get('editable')
      @regions =
        container: @itemViewContainer
      @sectionNameModal = new SectionNameModal({model: @model})
      super()
      @listenTo(@model, 'add change:unit change:title change:expanded sync:contents', @render)
      introPage = @model.introduction()
      if introPage
        @listenTo(introPage, 'change:active', @reflectIntroActive)

    onRender: () ->
      return if @model.get('visible') == false
      super()
      @regions.container.empty()
      nodes = @model.get('contents')?.models
      _.each nodes, (node) =>
        if node.get('visible')
          if node.isSection()
            @regions.container.appendAs 'li', new TocSectionView
              model: node
          else
            unless node is @model.introduction()
              @regions.container.appendAs 'li', new TocPageView
                model: node
                collection: @model
      @reflectIntroActive()

    toggleSection: () ->
      @model.set('expanded', not @model.get('expanded'))

    toggleSectionWithKeyboard: (e) ->
      if e.keyCode is 13 or e.keyCode is 32
        e.preventDefault()
        @toggleSection()
        @$el.find('> div > .section-wrapper').focus()

    toggleOrLoad: (e) ->
      e.stopPropagation()
      introPage = @model.introduction()
      if introPage
        book = @model.get('book')
        pageNumber = introPage.getPageNumber()
        info = {model: book, page: pageNumber}
        path = linksHelper.getPath('contents', info)
        book.setPage(pageNumber)
        router.navigate(path)
      else
        @toggleSection()

    reflectIntroActive: ->
      introPage = @model.introduction()
      return unless introPage
      $title = @$el.find('> div > span > .title')
      if @model.introduction().get('active')
        $title.addClass('active')
      else
        $title.removeClass('active')

    removeNode: () ->
      @content.removeNode(@model)

    editNode: () ->
      @regions.self.appendOnce
        view: @sectionNameModal
        as: 'div id="section-name-modal" class="modal fade"'
      @sectionNameModal.promptForValue(
        @model.attributes.title
        (newValue) =>
          @model.set('title', newValue)
          @model.set('changed', true)
          @model.get('book').set('childChanged', true)
          @model.get('book').set('changed', true))
      @sectionNameModal.$el.modal('show')
