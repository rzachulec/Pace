HStack{
                            VStack(alignment: .leading) {
                                Text("Current Task:")
                                Text("Code UI")
                                    .font(.title)
                                    .fontWeight(.semibold)
                                Text("\(minutesRemaining) m remaining")
                                    .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                                        minutesRemaining = Int((200-fillProgress)/60)
                                    }
                            }
                            
                            Spacer()
                            
                            Text("Hold for \n details")
                                .font(.caption)
                        }
                        .padding()
                        .background(
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(.gray)
                                    .foregroundColor(.white)
                                    .background(material)
                                Image("Background")
                                    .resizable()
                                    .scaledToFill()
                                    .clipShape(Rectangle())
                                    .frame(height: 130)
                                    .offset(y: offsetY-100)
                                    .padding(-10)
                                    .blur(radius: 15)
                                    .brightness(0.1)
                                    .mask(
                                        HStack {
                                            RoundedRectangle(cornerRadius: 20)
                                                .frame(width: geometry.size.width * fillProgress)
                                                .foregroundColor(Color(red: 0.476471, green: 0.927451, blue: 0.678431))
                                                .opacity(0.5)
                                                .onAppear {
                                                    withAnimation(Animation.linear(duration: 200).repeatForever(autoreverses: false)) {
                                                        fillProgress = 1
                                                    }
                                                }
                                            Spacer()
                                        }
                                    )
                            }
                        )
                        .contextMenu {
                            
                            VStack {
                                Button(action: { print("Cut") }) {
                                    Label("Cut", systemImage: "scissors")
                                }
                                Button(action: { print("Copy") }) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                Button(action: { print("Paste") }) {
                                    Label("Paste", systemImage: "doc.on.clipboard")
                                }
                            }
                            .presentationDetents([.medium])
                            .presentationBackground(.thinMaterial)
                            .presentationBackgroundInteraction(.automatic)
                            .padding()
                        }
                        .padding(.bottom, 15)