.sheet(isPresented: $showEditTask) {
                    VStack(spacing: 20) {
                        
                        Text("Edit Task")
                            .font(.headline)
                            .padding(.top)
                        
                        TextField("Event Title", text: $title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                        
                        // Date Picker
                        HStack {
                            DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                            Button(action: autoSelectDate) {
                                Image(systemName: "wand.and.stars")
                                    .foregroundColor(.blue)
                                    .padding(8.5)
                                    .padding(.horizontal)
                                    .scaleEffect(isDatePressed ? 1.2 : 1.0)
                                    .background(isDatePressed ? Color.blue.opacity(0.7) : Color.gray.opacity(0.15))
                                    .cornerRadius(8)
                            }
                            .simultaneousGesture(DragGesture(minimumDistance: 0)
                                .onChanged { _ in isDatePressed = true }
                                .onEnded { _ in isDatePressed = false }
                            )
                            .animation(.easeInOut(duration: 0.7), value: isDatePressed)
                        }
                        .padding(.horizontal)
                        
                        
                        HStack {
                            DatePicker("Start time", selection: $startTime,
                                       displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            Button(action: autoSelectTime) {
                                Image(systemName: "wand.and.stars")
                                    .foregroundColor(.blue)
                                    .padding(8.5)
                                    .padding(.horizontal)
                                    .scaleEffect(isTimePressed ? 1.2 : 1.0)
                                    .background(isTimePressed ? Color.blue.opacity(0.7) : Color.gray.opacity(0.15))
                                    .cornerRadius(8)
                            }
                            .simultaneousGesture(DragGesture(minimumDistance: 0)
                                .onChanged { _ in isTimePressed = true }
                                .onEnded { _ in isTimePressed = false }
                            )
                            .animation(.easeInOut(duration: 0.7), value: isTimePressed)
                        }
                        .padding(.horizontal)
                        
                        // Duration Picker
                        Picker("Duration", selection: $durationIndex) {
                            ForEach(0..<durations.count, id: \.self) { index in
                                Text("\(durations[index]) min").tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        // Add Button
                        Button(action: {
                            editEvent()
                            showEditTask.toggle()
                        }) {
                            Text("Update Task")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        
                        // Close Button
                        Button("Close") {
                            showEditTask.toggle()
                        }
                        .foregroundColor(.red)
                        
                        Spacer()
                    }