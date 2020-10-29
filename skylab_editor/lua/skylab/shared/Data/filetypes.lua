if not SSLE then 
	return 
end

SSLE.filetypes = {
    TEXT = 0,
    IMAGE = 1,
    VIDEO = 2,
    AUDIO = 3,
    CODE = 4
}

local ft = SSLE.filetypes 

SSLE.fileextensions = {}

local function add(extension, type, canWrite)
    if SSLE.fileextensions[extension] then return end 

    canWrite = canWrite or false 

    SSLE.fileextensions[extension] = {
        type     = type,
        canWrite = canWrite
    }
end

add("txt", ft.TEXT, true)
add("jpg", ft.IMAGE, true)
add("png", ft.IMAGE, true)
add("vtf", ft.IMAGE, true)
add("dat", ft.TEXT, true)
add("json", ft.CODE, true)
add("vmt", ft.IMAGE, true)

add("gif", ft.IMAGE)
add("ico", ft.IMAGE)

add("mp3", ft.AUDIO)
add("wav", ft.AUDIO)
add("ogg", ft.AUDIO)
add("mp3", ft.AUDIO)
add("opus", ft.AUDIO)

add("mp4", ft.VIDEO)
add("webm", ft.VIDEO)
add("flv", ft.VIDEO)

add("lua", ft.CODE)
add("cpp", ft.CODE)
add("c", ft.CODE)
add("h", ft.CODE)
add("cs", ft.CODE)
add("js", ft.CODE)
add("rs", ft.CODE)
add("py", ft.CODE)
add("java", ft.CODE)
add("html", ft.CODE)
add("css", ft.CODE)
add("sh", ft.CODE)
add("bat", ft.CODE)
add("md", ft.CODE)
add("toml", ft.CODE)
add("yaml", ft.CODE)

SSLE.imageextensions = {}
for k, v in pairs(SSLE.fileextensions) do 
    if v.type == ft.IMAGE then 
        SSLE.imageextensions[k] = v
    end
end

SSLE.textextensions = {}
for k, v in pairs(SSLE.fileextensions) do 
    if v.type == ft.TEXT then 
        SSLE.textextensions[k] = v
    end
end

SSLE.videoextensions = {}
for k, v in pairs(SSLE.fileextensions) do 
    if v.type == ft.VIDEO then 
        SSLE.videoextensions[k] = v
    end
end

SSLE.codeextensions = {}
for k, v in pairs(SSLE.fileextensions) do 
    if v.type == ft.CODE then 
        SSLE.codeextensions[k] = v
    end
end
