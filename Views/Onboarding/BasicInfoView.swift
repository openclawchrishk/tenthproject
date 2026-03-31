import SwiftUI

struct BasicInfoView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            Text("填寫基本資料")
                .font(.largeTitle)
                .bold()
                .padding(.top, 40)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("顯示名稱")
                    .font(.headline)
                
                TextField("你的稱呼", text: $viewModel.displayName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("地區")
                    .font(.headline)
                
                Picker("地區", selection: $viewModel.region) {
                    ForEach(["HK", "深圳", "廣州", "澳門", "海外港人", "其他 GBA", "其他地區"], id: \.self) { region in
                        Text(region).tag(region)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Commitment Level")
                    .font(.headline)
                
                Picker("投入程度", selection: $viewModel.commitmentLevel) {
                    ForEach(["全職", "兼職", "只看看"], id: \.self) { level in
                        Text(level).tag(level)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding(.horizontal)
            
            Spacer()
            
            Button(action: {
                viewModel.proceedToNextStep()
            }) {
                Text("下一步")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.displayName.isEmpty ? Color.gray : AppColor.primary)
                    .cornerRadius(12)
            }
            .disabled(viewModel.displayName.isEmpty)
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
    }
}

struct BasicInfoView_Previews: PreviewProvider {
    static var previews: some View {
        BasicInfoView(viewModel: OnboardingViewModel())
    }
}
