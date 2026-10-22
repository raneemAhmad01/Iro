//
//  AnxietyView.swift
//  Iro Project
//
//  Created by RaneemAhmad on 11/05/1448 AH.
//

import SwiftUI

struct AnxietyView: View {
    
    
    var body: some View {
        
        VStack{
            Text("Breathe").font(.title)
                .fontWeight(.semibold)
            
            Text("Inhale. Exhale. Reset.")
            Image(.zinaHairstyleByMlsthings).resizable()
                .frame(width: 300,  height: 300)

            
            
        }
        HStack{
            Button(action: {
                // Action goes here
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title)
                    
            }
            Button(action: {
                // Action goes here
            }) {
                Image(systemName: "play.fill")
                    .font(.title)
                    
            }

            
            
            
        }
        
        
        
    }
    
    
    
    
    
    
}


#Preview {
    AnxietyView()
}
