import TrieMap "mo:base/TrieMap";
import Buffer "mo:base/Buffer";
import JSON "mo:json/JSON";

module {

    // incoming http request data types
    public type HeaderField = (Text, Text);

    public type HttpRequest = {
        url     : Text;
        method  : Text;
        body    : Blob;
        headers : [HeaderField];
    };

    public type HttpResponse = {
        body        : Blob;
        headers     : [HeaderField];
        status_code : Nat16;
    };

    // Data types used by this module
    public type URL = {
        original: Text;
        protocol: Text ;
        port: Nat16; 
        host: {
            original: Text;
            array: [Text];
        };
        path: {
            original: Text;
            array: [Text];
        };
        queryObj: {
            original: Text;
            get: (Text) -> ?Text;
            trieMap: TrieMap.TrieMap<Text, Text>;
            keys: [Text]; 
        };
        anchor: Text; 
    };

    public type Form = {
        get: (Text) -> ?[Text];
        trieMap: TrieMap.TrieMap<Text, [Text]>;
        keys: [Text];
        
        fileKeys: [Text];
        files: (Text) -> ?[File];
    };

    public type Headers = {
        original: [(Text, Text)];
        get: (Text) -> ?[Text];
        trieMap: TrieMap.TrieMap<Text, [Text]>;
        keys: [Text];
    };

    public type File = {
        name: Text;
        filename: Text;
        
        mimeType: Text;
        mimeSubType: Text;

        start: Nat;
        end: Nat;
        bytes: Buffer.Buffer<Nat8>;
    };

    public type Body = {
        original: Blob;
        size: Nat; 
        form: Form;
        text: () -> Text; 
        deserialize: () -> ?JSON.JSON;
        file: () -> ?Buffer.Buffer<Nat8>; 
        bytes: (start: Nat, end: Nat) -> Buffer.Buffer<Nat8>;
    };

    public type FormObjType = {
        get: (Text) -> ?[Text];
        trieMap: TrieMap.TrieMap<Text, [Text]>;
        keys: [Text];
        
        fileKeys: [Text];
        files: (Text) -> ?[File];
    };

    public type ParsedHttpRequest = {
        method: Text;
        url: URL;
        headers: Headers;
        body: ?Body;
    };      

    // internal types
    public type FormDataType = {
        #urlencoded: ();

        // takes the boundary as an optional parameter
        #multipart: ?Text;
    };
}
