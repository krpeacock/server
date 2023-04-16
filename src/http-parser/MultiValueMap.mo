import Buffer "mo:base/Buffer";
import TrieMap "mo:base/TrieMap";
import Iter "mo:base/Iter";
import Hash "mo:base/Hash";

import Utils "Utils";

module {
    /// A Map extention of a TrieMap that can store multiple values for one key 
    /// Multiple values are stored in a Buffer and accessed/returned as an array
    public class MultiValueMap<K, V>(
        isKeyEq : (K, K) -> Bool,
        keyHash : K -> Hash.Hash
    ){

        let map = TrieMap.TrieMap<K, Buffer.Buffer<V>>(isKeyEq, keyHash);

        public let size = map.size;
        public let keys = map.keys;

        public func put(key:K, value:V): () {
            let buffer = Buffer.Buffer<V>(1);
            buffer.add(value);
            map.put(key, buffer);
        };

        public func putMany(key:K, values:[V]): (){
            let buffer = Utils.arrayToBuffer<V>(values);
            map.put(key, buffer);
        };

        public func add(key:K, value:V){
            switch(map.get(key)){
                case (?buffer){
                    buffer.add(value);
                    map.put(key, buffer);
                };
                case (_){
                    put(key, value);
                };
            };
        };

        public func addMany(key:K, values:[V]){
            switch(map.get(key)){
                case (?buffer){
                    buffer.append(Utils.arrayToBuffer<V>(values));
                    map.put(key, buffer);
                };
                case (_){
                    putMany(key, values);
                };
            };
        };

        func optBufferToArray(optionalBuffer: ?Buffer.Buffer<V>):?[V]{
            switch(optionalBuffer){
                case(?buffer){
                    ?buffer.toArray();
                };
                case(_){
                    null;
                };
            }
        };

        public func get(key: K): ?[V]{
            optBufferToArray(map.get(key))
        };

        public func vals(): Iter.Iter<[V]>{
            let iter = map.vals();

            return object {
                public func next(): ?[V]{
                    optBufferToArray(iter.next());
                };
            };
        };

        public func entries(): Iter.Iter<(K, [V])>{
            let iter = map.entries();

            return object {
                public func next(): ?(K, [V]){
                   switch (iter.next()){
                       case (?(key, buffer)){
                           ?(key, buffer.toArray())
                       };
                       case (_){
                           null
                       };
                   };
                };
            };
        };

        // returns a new TrieMap with the values stored in immutable arrays instead of buffers
        public func freezeValues(): TrieMap.TrieMap<K, [V]>{
            TrieMap.fromEntries<K, [V]>(entries(), isKeyEq, keyHash)
        };

        // returns a TrieMap where only the first value of each entry is stored
        public func toSingleValueMap(): TrieMap.TrieMap<K, V>{
            let singleValueMap = TrieMap.TrieMap<K, V>(isKeyEq, keyHash);

            for ((key, values) in entries()){
                singleValueMap.put(key, values[0]);
            };

            return singleValueMap;
        };

    };
};
