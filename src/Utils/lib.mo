import TrieMap "mo:base/TrieMap";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Result "mo:base/Result";
module {

  public type PathParams = TrieMap.TrieMap<Text, Text>;
  public type PathParamsResult = Result.Result<PathParams, Text>;
  public type PathPattern = Text;
  public type Path = Text;

  /** Parses the path parameters from the given path using the given pattern.
    *
    * @param pattern The pattern to use for parsing the path.
    * @param path The path to parse.
    * @returns A map of the parsed path parameters.
    * @example
    * let pattern = "/cats/:name";
    * let path = "/cats/sardine";
    * let map = Utils.parsePathParams(pattern, path);
    */
  public func parsePathParams(pattern : PathPattern, path : Path) : PathParamsResult {
    let map = TrieMap.TrieMap<Text, Text>(Text.equal, Text.hash);

    let patternParts = Iter.toArray(Text.split(pattern, #text "/"));
    let patternSize = patternParts.size();
    let pathParts = Iter.toArray(Text.split(path, #text "/"));
    let pathSize = pathParts.size();

    if (patternSize != pathSize) {
      return #err("Pattern and path have different number of parts.");
    };

    let paramPrefix = #text ":";

    for (i in Iter.range(0, patternSize - 1)) {

      if (Text.startsWith(patternParts[i], paramPrefix)) {
        // Trim the param prefix
        let paramName = Text.stripStart(patternParts[i], paramPrefix);

        switch paramName {
          case null {
            return #err("bad parameter name: " # patternParts[i]);
          };
          case (?name) {
            // Check if the param name is empty
            if (Text.size(name) == 0) {
              return #err("bad parameter name: " # patternParts[i]);
            };
            if(map.get(name) != null) {
              return #err("duplicate parameter name: " # name);
            };
            // Add the param to the map
            map.put(name, pathParts[i]);
          };
        };
      };
    };

    #ok map;
  };

  public func showPathParamsResult(result : PathParamsResult) : Text {
    switch result {
      case (#ok map) {
        return debug_show (Iter.toArray(map.entries()));
      };
      case (#err err) {
        return "err " # err;
      };
    };
  };

  public func pathParamsResultEqual(a : PathParamsResult, b : PathParamsResult) : Bool {
    switch (a, b) {
      case ((#ok a), (#ok b)) {
        let isEqual = Array.equal(
          Iter.toArray(a.entries()),
          Iter.toArray(b.entries()),
          func(a : (Text, Text), b : (Text, Text)) : Bool {
            return a == b;
          },
        );

        if (not isEqual) {
          return false;
        };
        return true;

      };
      case ((#err a), (#err b)) {
        return a == b;
      };
      case _ {
        return false;
      };
    };
  };
};
