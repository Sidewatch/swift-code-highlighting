//
//  DockerfileRules.swift
//  CodeHighlighting
//
//  The regex rule table for Dockerfile.
//
//  Created by David Sherlock on 9/5/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The regex rule table for Dockerfile.
/// Later rules repaint earlier ones; strings and comments paint last.
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
