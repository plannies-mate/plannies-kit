# frozen_string_literal: true

class HTMLFilter
  # Standard HTML5 elements
  HTML_ELEMENTS = Set.new(%w[
    a abbr address area article aside audio b base bdi bdo blockquote body br
    button canvas caption cite code col colgroup data datalist dd del details dfn
    dialog div dl dt em embed fieldset figcaption figure footer form h1 h2 h3 h4
    h5 h6 head header hgroup hr html i iframe img input ins kbd label legend li
    link main map mark menu meta meter nav noscript object ol optgroup option
    output p param picture pre progress q rp rt ruby s samp script section select
    slot small source span strong style sub summary sup table tbody td template
    textarea tfoot th thead time title tr track u ul var video wbr
  ])

  # Common HTML5 global attributes
  GLOBAL_ATTRIBUTES = Set.new(%w[
    accesskey class contenteditable dir draggable hidden id lang spellcheck style
    tabindex title translate
  ])

  # Common element-specific attributes
  SPECIFIC_ATTRIBUTES = Set.new(%w[
    accept accept-charset action alt async autocomplete autofocus autoplay charset
    checked cite colspan content controls coords datetime default defer disabled
    download enctype for form formaction headers height href hreflang http-equiv
    integrity kind label list loop max maxlength media method min minlength
    multiple muted name novalidate open optimum pattern placeholder poster preload
    readonly rel required reversed rows rowspan sandbox scope selected shape size
    sizes span src srcdoc srclang srcset start step target type usemap value
    width wrap
  ])

  # ARIA attributes
  ARIA_ATTRIBUTES = Set.new(%w[
    role aria-activedescendant aria-atomic aria-autocomplete aria-busy
    aria-checked aria-colcount aria-colindex aria-colspan aria-controls
    aria-current aria-describedby aria-details aria-disabled aria-dropeffect
    aria-errormessage aria-expanded aria-flowto aria-grabbed aria-haspopup
    aria-hidden aria-invalid aria-keyshortcuts aria-label aria-labelledby
    aria-level aria-live aria-modal aria-multiline aria-multiselectable
    aria-orientation aria-owns aria-placeholder aria-posinset aria-pressed
    aria-readonly aria-relevant aria-required aria-roledescription aria-rowcount
    aria-rowindex aria-rowspan aria-selected aria-setsize aria-sort aria-valuemax
    aria-valuemin aria-valuenow aria-valuetext
  ])

  def self.html_token?(str)
    str = str.downcase
    HTML_ELEMENTS.include?(str) ||
      GLOBAL_ATTRIBUTES.include?(str) ||
      SPECIFIC_ATTRIBUTES.include?(str) ||
      ARIA_ATTRIBUTES.include?(str) ||
      str.start_with?('aria-') # Custom ARIA (allow data- attributes)
  end

  # def self.html_tokens
  #   HTML_ELEMENTS.to_a.sort +
  #     GLOBAL_ATTRIBUTES.to_a.sort +
  #     SPECIFIC_ATTRIBUTES.to_a.sort +
  #     ARIA_ATTRIBUTES.to_a.sort
  # end
end

# Update ScraperAnalyzer to use the filter

