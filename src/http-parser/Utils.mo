import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Char "mo:base/Char";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Option "mo:base/Option";
import Text "mo:base/Text";
import Result "mo:base/Result";

import ArrayModule "mo:array/Array";
import Hex "mo:encoding/Hex";
import JSON "mo:json/JSON";

module {
    public func textToNat( txt : Text) : Nat {
        assert(txt.size() > 0);
        let chars = txt.chars();
        var num : Nat = 0;
        for (v in chars){
            let charToNum = Nat32.toNat(Char.toNat32(v)-48);
            assert(charToNum >= 0 and charToNum <= 9);
            num := num * 10 +  charToNum;          
        };
        num;
    };

    func charToLowercase(c: Char): Char{
        if (Char.isUppercase(c)){
            let n = Char.toNat32(c);

            //difference between the nat32 values of 'a' and 'A'
            let diff:Nat32 = 32;
            return Char.fromNat32( n + diff);
        };

        return c;
    };

    public func toLowercase(text: Text): Text{
        var lowercase = "";

        for (c in text.chars()){
            lowercase:= lowercase # Char.toText(charToLowercase(c));
        };

        return lowercase;
    };

    public func arrayToBuffer <T>(arr: [T]): Buffer.Buffer<T>{
        let buffer = Buffer.Buffer<T>(arr.size());
        for (n in arr.vals()){
            buffer.add(n);
        };
        return buffer;
    };

    public func arraySliceToBuffer<T>(arr: [T], start: Nat, end: Nat): Buffer.Buffer<T>{
        let slice = ArrayModule.slice(arr, start, end);
        let buffer = arrayToBuffer<T>(slice);
        return buffer;
    };

    public func nat8ToChar(n8: Nat8): Char{
        let n = Nat8.toNat(n8);
        let n32 = Nat32.fromNat(n);
        Char.fromNat32(n32);
    };

    public func charToNat8(char: Char): Nat8{
        let n32 = Char.toNat32(char);
        let n = Nat32.toNat(n32);
        let n8 = Nat8.fromNat(n);
    };

    public func enumerate<A>(iter: Iter.Iter<A> ): Iter.Iter<(Nat, A)> {
        var i =0;
        return object{
            public func next ():?(Nat, A) {
                let nextVal = iter.next();

                switch nextVal {
                    case (?v) {
                        let val = ?(i, v);
                        i+= 1;

                        return val;
                    };
                    case (_) null;
                };
            };
        };
    };

    // A predicate for matching any char in the given text
    func matchAny(text: Text): Text.Pattern{
        func pattern(c: Char): Bool{
            Text.contains(text, #char c);
        };

        return #predicate pattern;
    };

    public func trimEOL(text: Text): Text{
        return Text.trim(text, matchAny("\n\r"));
    };

    public func trimSpaces(text: Text): Text{
        return Text.trim(text, matchAny("\t "));
    };

    public func trimQuotes(text: Text): Text{
        return Text.trim(text, #text("\""));
    };

    public func textToBytes(text: Text): [Nat8]{
        let blob = Text.encodeUtf8(text);
        Blob.toArray(blob)
    };

    public func bytesToText(bytes:[Nat8]): ?Text {
        Text.decodeUtf8(Blob.fromArray(bytes))
    };

    public func encodeURIComponent(t: Text): Text{
        var encoded = "";

        for (c in t.chars()){
            let cAsText =  Char.toText(c);
            if (Text.contains(cAsText, matchAny("'()*-._~")) or Char.isAlphabetic(c) or Char.isDigit(c) ){
                encoded := encoded # Char.toText(c);
            }else{
                let hex = Hex.encodeByte(charToNat8(c));
                encoded := encoded # "%" # hex;
            };
        };
        encoded
    };

    public func subText(value : Text, indexStart: Nat, indexEnd : Nat) : Text {
        if (indexStart == 0 and indexEnd >= value.size()) {
            return value;
        };
        if (indexStart >= value.size()) {
            return "";
        };

        var result : Text = "";
        var i : Nat = 0;
        label l for (c in value.chars()) {
            if (i >= indexStart and i < indexEnd) {
                result := result # Char.toText(c);
            };
            if (i == indexEnd) {
                break l;
            };
            i += 1;
        };

        result;
    };

    public func decodeURIComponent(t: Text): ?Text{
        let iter = Text.split(t, #char '%');
        var decodedURI = Option.get(iter.next(), "");

        for (sp in iter){
            let hex = subText(sp, 0, 2);
            
            switch(Hex.decode(hex)){
                case(#ok(symbols)){
                    let char = (nat8ToChar(symbols[0]));
                    decodedURI := decodedURI # Char.toText(char) # 
                                Text.trimStart(sp, #text hex);
                };
                case(_){
                   return null;
                };
            };

        };

        ?decodedURI
    };

}
