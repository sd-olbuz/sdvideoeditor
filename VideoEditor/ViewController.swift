//
//  ViewController.swift
//  VideoEditor
//
//  Created by Nitin Gohel on 16/05/25.
//

import UIKit
import PhotosUI

class ViewController: UIViewController {
    
    private let pickVideoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Pick Video", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        //Saurav
    }
    
    private func setupUI() {
        
        view.backgroundColor = .white
        view.addSubview(pickVideoButton)
        NSLayoutConstraint.activate([
            pickVideoButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pickVideoButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        pickVideoButton.addTarget(self, action: #selector(pickVideoButtonTapped), for: .touchUpInside)
    }
    
    @objc private func pickVideoButtonTapped() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
}

extension ViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let result = results.first else { return }
        
        result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
            if let error = error {
                print("Error loading video: \(error.localizedDescription)")
                return
            }
            
            if let url = url {
                print("Selected video URL: \(url)")
                // Copy the file to the app's documents directory
                let fileManager = FileManager.default
                let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                let destURL = docs.appendingPathComponent(url.lastPathComponent)
                try? fileManager.removeItem(at: destURL)
                do {
                    try fileManager.copyItem(at: url, to: destURL)
                    DispatchQueue.main.async {
                        let editorVC = self.storyboard?.instantiateViewController(withIdentifier: "VideoEditorViewController") as! VideoEditorViewController
                        editorVC.videoURL = destURL
                        editorVC.modalPresentationStyle = .fullScreen
                        editorVC.tintColor = .red
                        self.present(editorVC, animated: true)
                    }
                } catch {
                    print("Failed to copy video: \(error)")
                }
            }
        }
    }
}

