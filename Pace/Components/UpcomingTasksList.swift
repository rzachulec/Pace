//
//  UpcomingTasks.swift
//  Pace
//
//  Created by jan on 14/02/2025.
//

import SwiftUI

struct UpcomingTasks: View {
    var body: some View {
        
        VStack(alignment: .leading) {
            HStack{
                Text("Upcoming Tasks:")
                Spacer()
            }
            ScrollView() {
                VStack() {
                    Divider()
                    
                    HStack {
                        Text("Gym")
                            .font(.title2)
                        Spacer()
                        Text("6 PM - 2 h")
                    }
                    Divider()
                    
                    HStack {
                        Text("Shopping")
                            .font(.title2)
                        Spacer()
                        Text("8 PM - 1 h")
                    }
                    Divider()
                    
                    HStack {
                        Text("Cook dinner")
                            .font(.title2)
                        Spacer()
                        Text("9 PM - 1 h")
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Read")
                            .font(.title2)
                        Spacer()
                        Text("10 PM - 30 m")
                    }
                    Divider()
                    
                    HStack {
                        Text("Read")
                            .font(.title2)
                        Spacer()
                        Text("10 PM - 30 m")
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Read")
                            .font(.title2)
                        Spacer()
                        Text("10 PM - 30 m")
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Read")
                            .font(.title2)
                        Spacer()
                        Text("10 PM - 30 m")
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.gray)
        )
        .padding(.bottom, 15)
    }
}

#Preview {
    UpcomingTasks()
}
