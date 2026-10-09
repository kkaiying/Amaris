//
//  StarRating.swift
//  Amaris
//
//  Five stars filled to any fraction, so quarter stars (3.75) render correctly.
//

import SwiftUI

struct StarRating: View {
    let rating: Double
    var maxRating = 5

    var body: some View {
        stars
            .foregroundStyle(.quaternary)
            .overlay {
                stars
                    .foregroundStyle(.orange)
                    .mask(alignment: .leading) {
                        GeometryReader { geometry in
                            Rectangle()
                                .frame(width: geometry.size.width * min(max(rating / Double(maxRating), 0), 1))
                        }
                    }
            }
            .accessibilityElement()
            .accessibilityLabel("\(rating.formatted()) out of \(maxRating) stars")
    }

    private var stars: some View {
        HStack(spacing: 1) {
            ForEach(0..<maxRating, id: \.self) { _ in
                Image(systemName: "star.fill")
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        StarRating(rating: 3.75).frame(height: 16)
        StarRating(rating: 5).frame(height: 16)
        StarRating(rating: 0.25).frame(height: 16)
    }
    .padding()
}
