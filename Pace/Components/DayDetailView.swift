.sheet(isPresented: $showDayView) {
                        VStack  {
                            Text("\(day.day)")
                            HStack{
                                Text("Tasks:")
                                Spacer()
                            }
                            .padding()
                            UpcomingTasksList()
                        }
                        .padding(.top, 30)
                        .presentationDetents([.medium, .large])
                    }