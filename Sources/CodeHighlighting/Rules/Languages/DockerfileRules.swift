import Foundation

/// The regex rule table for Dockerfile. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let dockerfile: [(String, TokenKind)] = [
        hashComment,
        doubleQuoted,
        singleQuotedPlain,
        ("(?i)^\\s*(FROM|RUN|CMD|LABEL|EXPOSE|ENV|ADD|COPY|ENTRYPOINT|VOLUME|USER|WORKDIR|ARG|ONBUILD|STOPSIGNAL|HEALTHCHECK|SHELL|MAINTAINER)\\b", .keyword),
        ("\\$\\{?[a-zA-Z_]\\w*\\}?", .type),
        ("\\b\\d+\\b", .number),
    ]
}
