pub usingnamespace @cImport({
    @cDefine("LIBXML_READER_ENABLED", {});
    @cDefine("LIBXML_WRITER_ENABLED", {});
    @cInclude("libxml/xmlreader.h");
    @cInclude("libxml/xmlwriter.h");
});
