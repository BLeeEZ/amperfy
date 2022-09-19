//
//  ServerSettingsView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 14.09.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import SwiftUI

struct ServerSettingsView: View {
    
    @State var isPwUpdateDialogVisible: Bool = false
    
    var body: some View {
        ZStack{
            List {
                Section() {
                    VStack(alignment: .leading) {
                        Text("URL")
                            .padding([.bottom], 2)
                        Text(appDelegate.storage.loginCredentials?.serverUrl ?? "")
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading) {
                        Text("Username")
                            .padding([.bottom], 2)
                        Text(appDelegate.storage.loginCredentials?.username ?? "")
                            .foregroundColor(.secondary)
                    }
                }

                Section() {
                    HStack {
                        Text("Backend API")
                        Spacer()
                        Text(appDelegate.storage.loginCredentials?.backendApi.description ?? "")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Server API Version")
                        Spacer()
                        Text(appDelegate.backendApi.serverApiVersion)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Client API Version")
                        Spacer()
                        Text(appDelegate.backendApi.clientApiVersion)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section() {
                    NavigationLink(destination: ServerURLsSettingsView()) {
                        Text("Manage Server URLs")
                    }
                }
                
                Section() {
                    Button(action: {
                        withPopupAnimation { isPwUpdateDialogVisible = true }
                    }) {
                        Text("Update Password")
                    }
                }
            }
        }
        .navigationTitle("Server")
        .sheet(isPresented: $isPwUpdateDialogVisible) {
            UpdatePasswordView(isVisible: $isPwUpdateDialogVisible)
        }
    }
}

struct ServerSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ServerSettingsView()
    }
}
