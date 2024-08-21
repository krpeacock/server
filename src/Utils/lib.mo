import TrieMap "mo:base/TrieMap";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Result "mo:base/Result";
import HttpParser "mo:http-parser";

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

    // Convert the pattern and path to lowercase for case-insensitive comparison
    let patternLower = Text.toLowercase(pattern);
    let pathLower = Text.toLowercase(path);

    let patternParts = Iter.toArray(Text.split(patternLower, #text "/"));
    let patternSize = patternParts.size();
    let pathParts = Iter.toArray(Text.split(pathLower, #text "/"));
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
            if (map.get(name) != null) {
              return #err("duplicate parameter name: " # name);
            };

            var part = pathParts[i];
            // remove any query parameters
            switch (Text.split(part, #text "?").next()) {
              case (?p) {
                part := p;
              };
              case null {};
            };

            // remove any anchor
            switch (Text.split(part, #text "#").next()) {
              case (?p) {
                part := p;
              };
              case null {};
            };

            // Add the param to the map
            map.put(name, part);
          };
        };
      } else {
        if (patternParts[i] != pathParts[i]) {
          return #err("Path does not match the pattern. Expected: " # patternParts[i] # ", got: " # pathParts[i]);
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

  public func simplifyRoute(url : HttpParser.URL) : (Text, Text) {
    let parts = Iter.fromArray(url.path.array);
    let simplified = Iter.filter(
      parts,
      func(part : Text) : Bool {
        return Text.size(part) > 0;
      },
    );
    let baseRoute : Text = "/" # Text.join("/", simplified);
    var fullRoute = baseRoute;

    if (url.queryObj.original.size() > 0) {
      fullRoute := fullRoute # "?" # url.queryObj.original;
    };

    if (url.anchor.size() > 0) {
      fullRoute := fullRoute # "#" # url.anchor;
    };

    (Text.toLowercase((baseRoute)), Text.toLowercase(fullRoute));
  };
};
