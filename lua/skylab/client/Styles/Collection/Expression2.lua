local e2style = {
    -- E2 Specific 
    preprocDirective = Color(240,240,160),
    preprocLine      = Color(240,240,160),
    includeDirective = Color(160,240,240),
    ppcommands       = Color(240,96,240),

    -- General stuff 
    operators        = Color(255,255,255),
    scopes           = Color(255,255,255),
    parenthesis      = Color(255,255,255),
    strings          = Color(150,150,150),
    comments         = Color(128,128,128),
    lineComment      = Color(128,128,128),
    variables        = Color(160,240,160),
    decimals         = Color(247,167,167),
    hexadecimals     = Color(247,167,167),
    keywords         = Color(160,240,240),
    builtinFunctions = Color(160,160,240),  
    userfunctions    = Color(102,122,102),
    types            = Color(240,160,96),
    constants        = Color(240,160,240),
    error            = Color(241,96,96),
    others           = Color(241,96,96)
}

SSLE.RegisterStyle("Expression2", "Default", e2style)